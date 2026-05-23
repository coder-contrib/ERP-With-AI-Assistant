from sqlalchemy.orm import Session
from decimal import Decimal
from app.repositories.sales_repo import SalesRepository
from app.repositories.customer_repo import CustomerRepository
from app.services.inventory_service import InventoryService
from app.services.cash_service import CashService
from app.services.ledger_service import LedgerService
from app.schemas.sales import SalesInvoiceCreate
from app.models.sales import SalesInvoice
from app.core.exceptions import NotFoundError, ValidationError


class SalesService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = SalesRepository(db)
        self.customer_repo = CustomerRepository(db)
        self.inventory = InventoryService(db)
        self.cash = CashService(db)
        self.ledger = LedgerService(db)

    def list_invoices(self) -> list[SalesInvoice]:
        return self.repo.get_all()

    def get_invoice(self, invoice_id: int) -> SalesInvoice:
        invoice = self.repo.get_by_id(invoice_id)
        if not invoice:
            raise NotFoundError("Sales invoice not found")
        return invoice

    def create_invoice(self, data: SalesInvoiceCreate) -> SalesInvoice:
        # 1. Validate credit invoice has customer
        if data.invoice_type == "credit" and not data.customer_id:
            raise ValidationError("Credit invoices require a customer")

        # 2. Validate credit limit
        if data.invoice_type == "credit" and data.customer_id:
            customer = self.customer_repo.get_by_id(data.customer_id)
            if not customer:
                raise NotFoundError("Customer not found")
            total = sum(item.total_price for item in data.items)
            if customer.credit_limit > 0 and (customer.current_balance + total) > customer.credit_limit:
                raise ValidationError(
                    f"Credit limit exceeded. Limit: {customer.credit_limit}, "
                    f"Current balance: {customer.current_balance}, Invoice: {total}"
                )

        # 3. Validate stock availability
        for item_data in data.items:
            stock = self.inventory.get_available_quantity(item_data.product_id, data.warehouse_id)
            if stock < item_data.sold_quantity:
                raise ValidationError(
                    f"Insufficient stock for product {item_data.product_id}. "
                    f"Available: {stock}, Requested: {item_data.sold_quantity}"
                )

        # 4. Calculate totals
        total_amount = sum(item.total_price for item in data.items)
        remaining = total_amount - data.discount_amount - data.paid_amount
        payment_status = self._calc_payment_status(data.paid_amount, remaining)

        # 5. Create invoice
        invoice = self.repo.create_invoice(
            customer_id=data.customer_id,
            invoice_number=data.invoice_number,
            invoice_type=data.invoice_type,
            warehouse_id=data.warehouse_id,
            total_amount=total_amount,
            discount_amount=data.discount_amount,
            paid_amount=data.paid_amount,
            remaining_amount=max(remaining, Decimal("0")),
            payment_status=payment_status,
            warehouse_notes=data.warehouse_notes,
            notes=data.notes,
        )

        # 6. Create items + inventory transactions
        for item_data in data.items:
            self.repo.create_item(
                invoice_id=invoice.invoice_id,
                **item_data.model_dump(),
            )
            self.inventory.record_sale(
                product_id=item_data.product_id,
                warehouse_id=data.warehouse_id,
                quantity=item_data.sold_quantity,
                unit_type=item_data.unit_type,
                cost_per_unit=item_data.cost_at_sale,
                reference_id=invoice.invoice_id,
            )

        # 7. Record cash transaction
        if data.paid_amount > 0:
            self.cash.record_cash_in(
                amount=data.paid_amount,
                entity_type="sales_invoice",
                entity_id=invoice.invoice_id,
            )

        # 8. Create ledger entries (double-entry)
        self.ledger.record_sale(
            invoice_id=invoice.invoice_id,
            total_amount=total_amount,
            cogs=sum(item.sold_quantity * item.cost_at_sale for item in data.items),
            cash_received=data.paid_amount,
            is_credit=(data.invoice_type == "credit"),
        )

        # 9. Update customer balance for credit sales
        if data.invoice_type == "credit" and data.customer_id:
            self.customer_repo.update_balance(customer, remaining)

        self.db.commit()
        self.db.refresh(invoice)
        return invoice

    def _calc_payment_status(self, paid: Decimal, remaining: Decimal) -> str:
        if remaining <= 0:
            return "paid"
        if paid > 0:
            return "partial"
        return "unpaid"
