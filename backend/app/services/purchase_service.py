from sqlalchemy.orm import Session
from decimal import Decimal
from app.database import transaction
from app.repositories.purchase_repo import PurchaseRepository
from app.repositories.supplier_repo import SupplierRepository
from app.services.inventory_service import InventoryService
from app.services.cash_service import CashService
from app.services.ledger_service import LedgerService
from app.schemas.purchases import PurchaseInvoiceCreate
from app.models.purchases import PurchaseInvoice
from app.core.exceptions import NotFoundError


class PurchaseService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = PurchaseRepository(db)
        self.supplier_repo = SupplierRepository(db)
        self.inventory = InventoryService(db)
        self.cash = CashService(db)
        self.ledger = LedgerService(db)

    def list_invoices(self) -> list[PurchaseInvoice]:
        return self.repo.get_all()

    def get_invoice(self, purchase_invoice_id: int) -> PurchaseInvoice:
        invoice = self.repo.get_by_id(purchase_invoice_id)
        if not invoice:
            raise NotFoundError("Purchase invoice not found")
        return invoice

    def create_invoice(self, data: PurchaseInvoiceCreate) -> PurchaseInvoice:
        with transaction(self.db):
            # 1. Validate supplier exists
            supplier = self.supplier_repo.get_by_id(data.supplier_id)
            if not supplier:
                raise NotFoundError("Supplier not found")

            # 2. Calculate totals
            total_amount = sum(item.total_cost for item in data.items)
            remaining = total_amount - data.paid_amount
            payment_status = "paid" if remaining <= 0 else ("partial" if data.paid_amount > 0 else "unpaid")

            # 3. Create invoice
            invoice = self.repo.create_invoice(
                supplier_id=data.supplier_id,
                invoice_number=data.invoice_number,
                total_amount=total_amount,
                paid_amount=data.paid_amount,
                remaining_amount=max(remaining, Decimal("0")),
                payment_status=payment_status,
                notes=data.notes,
            )

            # 4. Create items + inventory transactions
            for item_data in data.items:
                self.repo.create_item(
                    purchase_invoice_id=invoice.purchase_invoice_id,
                    **item_data.model_dump(),
                )
                self.inventory.record_purchase(
                    product_id=item_data.product_id,
                    warehouse_id=data.warehouse_id,
                    quantity=item_data.purchased_quantity,
                    unit_type=data.unit_type,
                    cost_per_unit=item_data.purchase_price,
                    reference_id=invoice.purchase_invoice_id,
                )

            # 5. Record cash transaction
            if data.paid_amount > 0:
                self.cash.record_cash_out(
                    amount=data.paid_amount,
                    entity_type="purchase_invoice",
                    entity_id=invoice.purchase_invoice_id,
                )

            # 6. Create ledger entries
            self.ledger.record_purchase(
                purchase_invoice_id=invoice.purchase_invoice_id,
                total_amount=total_amount,
                cash_paid=data.paid_amount,
                is_credit=(remaining > 0),
            )

            # 7. Update supplier balance for unpaid amount
            if remaining > 0:
                self.supplier_repo.update_balance(supplier, remaining)

        self.db.refresh(invoice)
        return invoice
