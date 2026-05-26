from sqlalchemy.orm import Session
from decimal import Decimal
from dataclasses import asdict
from app.database import transaction
from app.repositories.sales_repo import SalesRepository
from app.repositories.customer_repo import CustomerRepository
from app.services.inventory_service import InventoryService
from app.services.cash_service import CashService
from app.services.ledger_service import LedgerService
from app.core.validators import Validator
from app.events.event_bus import Event, get_event_bus
from app.events.sale_events import SALE_CREATED, SALE_RETURNED, SaleCreatedData
from app.core.exceptions import NotFoundError, ValidationError
from app.schemas.sales import SalesInvoiceCreate, SalesReturnCreate
from app.models.sales import SalesInvoice, SalesReturn


class SalesService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = SalesRepository(db)
        self.customer_repo = CustomerRepository(db)
        self.inventory = InventoryService(db)
        self.cash = CashService(db)
        self.ledger = LedgerService(db)
        self.validator = Validator(db)
        self.event_bus = get_event_bus()

    def list_invoices(self) -> list[SalesInvoice]:
        return self.repo.get_all()

    def get_invoice(self, invoice_id: int) -> SalesInvoice:
        invoice = self.repo.get_by_id(invoice_id)
        if not invoice:
            raise NotFoundError("Sales invoice not found")
        return invoice

    def create_invoice(self, data: SalesInvoiceCreate) -> SalesInvoice:
        with transaction(self.db):
            # --- VALIDATION ---
            if data.invoice_type in ("credit", "mixed") and not data.customer_id:
                raise ValidationError("Credit and mixed invoices require a customer")

            total_amount = sum(item.total_price for item in data.items)

            if data.invoice_type in ("credit", "mixed") and data.customer_id:
                self.validator.validate_credit_limit(data.customer_id, total_amount)

            for item_data in data.items:
                self.validator.validate_quantity(item_data.sold_quantity, "Sold quantity")
                self.validator.validate_product_active(item_data.product_id)
                self.validator.validate_unit_type_for_product(item_data.product_id, item_data.unit_type)
                self.validator.validate_stock_available(item_data.product_id, data.warehouse_id, item_data.sold_quantity)

            # --- EXECUTION ---
            remaining = total_amount - data.discount_amount - data.paid_amount
            payment_status = self._calc_payment_status(data.paid_amount, remaining)

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

            if data.paid_amount > 0:
                self.cash.record_cash_in(
                    amount=data.paid_amount,
                    entity_type="sales_invoice",
                    entity_id=invoice.invoice_id,
                )

            self.ledger.record_sale(
                invoice_id=invoice.invoice_id,
                total_amount=total_amount,
                cogs=sum(item.sold_quantity * item.cost_at_sale for item in data.items),
                cash_received=data.paid_amount,
                is_credit=(data.invoice_type in ("credit", "mixed")),
            )

            if data.invoice_type in ("credit", "mixed") and data.customer_id and remaining > 0:
                customer = self.customer_repo.get_by_id(data.customer_id)
                self.customer_repo.update_balance(customer, remaining)

        # --- PUBLISH EVENT (after commit) ---
        self.db.refresh(invoice)
        self.event_bus.publish(Event(
            event_type=SALE_CREATED,
            data={
                "invoice_id": invoice.invoice_id,
                "invoice_number": invoice.invoice_number,
                "invoice_type": data.invoice_type,
                "customer_id": data.customer_id,
                "warehouse_id": data.warehouse_id,
                "total_amount": str(total_amount),
                "discount_amount": str(data.discount_amount),
                "paid_amount": str(data.paid_amount),
                "remaining_amount": str(max(remaining, Decimal("0"))),
                "items": [item.model_dump() for item in data.items],
            },
        ))
        return invoice

    def _calc_payment_status(self, paid: Decimal, remaining: Decimal) -> str:
        if remaining <= 0:
            return "paid"
        if paid > 0:
            return "partial"
        return "unpaid"

    def process_return(self, invoice_id: int, data: SalesReturnCreate) -> SalesReturn:
        with transaction(self.db):
            invoice = self.repo.get_by_id(invoice_id)
            if not invoice:
                raise NotFoundError("Sales invoice not found")

            if not data.items:
                raise ValidationError("At least one item is required for a return")

            invoice_items = self.repo.get_items(invoice_id)
            item_map = {item.product_id: item for item in invoice_items}

            for ret_item in data.items:
                orig = item_map.get(ret_item.product_id)
                if not orig:
                    raise ValidationError(f"Product {ret_item.product_id} not found in this invoice")
                if ret_item.returned_quantity > orig.sold_quantity:
                    raise ValidationError(
                        f"Return quantity ({ret_item.returned_quantity}) exceeds sold quantity ({orig.sold_quantity})"
                    )

            returned_amount = sum(item.total for item in data.items)
            refund_amount = min(data.refund_amount, returned_amount)

            sales_return = self.repo.create_return(
                original_invoice_id=invoice_id,
                customer_id=invoice.customer_id,
                returned_amount=returned_amount,
                refund_amount=refund_amount,
                notes=data.notes,
            )

            cogs_total = Decimal("0")
            for ret_item in data.items:
                self.repo.create_return_item(
                    return_id=sales_return.return_id,
                    product_id=ret_item.product_id,
                    returned_quantity=ret_item.returned_quantity,
                    unit_price=ret_item.unit_price,
                    total=ret_item.total,
                )
                orig = item_map[ret_item.product_id]
                cogs_total += ret_item.returned_quantity * orig.cost_at_sale

                self.inventory.record_return(
                    product_id=ret_item.product_id,
                    warehouse_id=invoice.warehouse_id,
                    quantity=ret_item.returned_quantity,
                    unit_type=orig.unit_type,
                    cost_per_unit=orig.cost_at_sale,
                    reference_id=sales_return.return_id,
                )

            if refund_amount > 0:
                self.cash.record_cash_out(
                    amount=refund_amount,
                    entity_type="sales_return",
                    entity_id=sales_return.return_id,
                )

            self.ledger.record_sales_return(
                return_id=sales_return.return_id,
                returned_amount=returned_amount,
                refund_amount=refund_amount,
                cogs=cogs_total,
            )

            if invoice.customer_id and invoice.invoice_type in ("credit", "mixed"):
                credit_reduction = returned_amount - refund_amount
                if credit_reduction > 0:
                    customer = self.customer_repo.get_by_id(invoice.customer_id)
                    self.customer_repo.update_balance(customer, -credit_reduction)

            invoice.total_amount -= returned_amount
            invoice.remaining_amount = max(invoice.remaining_amount - (returned_amount - refund_amount), Decimal("0"))
            invoice.paid_amount = max(invoice.paid_amount - refund_amount, Decimal("0"))
            invoice.payment_status = self._calc_payment_status(invoice.paid_amount, invoice.remaining_amount)
            self.db.flush()

        self.db.refresh(sales_return)
        self.event_bus.publish(Event(
            event_type=SALE_RETURNED,
            data={
                "return_id": sales_return.return_id,
                "original_invoice_id": invoice_id,
                "customer_id": invoice.customer_id,
                "returned_amount": str(returned_amount),
                "refund_amount": str(refund_amount),
                "items": [item.model_dump() for item in data.items],
            },
        ))
        return sales_return
