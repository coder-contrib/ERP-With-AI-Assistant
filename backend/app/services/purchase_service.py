from sqlalchemy.orm import Session
from decimal import Decimal
from app.repositories.purchase_repo import PurchaseRepository
from app.services.inventory_service import InventoryService
from app.services.cash_service import CashService
from app.schemas.purchases import PurchaseInvoiceCreate
from app.models.purchases import PurchaseInvoice
from app.core.exceptions import NotFoundError


class PurchaseService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = PurchaseRepository(db)
        self.inventory = InventoryService(db)
        self.cash = CashService(db)

    def list_invoices(self) -> list[PurchaseInvoice]:
        return self.repo.get_all()

    def get_invoice(self, purchase_invoice_id: int) -> PurchaseInvoice:
        invoice = self.repo.get_by_id(purchase_invoice_id)
        if not invoice:
            raise NotFoundError("Purchase invoice not found")
        return invoice

    def create_invoice(self, data: PurchaseInvoiceCreate) -> PurchaseInvoice:
        total_amount = sum(item.total_cost for item in data.items)
        remaining = total_amount - data.paid_amount
        payment_status = "paid" if remaining <= 0 else ("partial" if data.paid_amount > 0 else "unpaid")

        invoice = self.repo.create_invoice(
            supplier_id=data.supplier_id,
            invoice_number=data.invoice_number,
            total_amount=total_amount,
            paid_amount=data.paid_amount,
            remaining_amount=max(remaining, Decimal("0")),
            payment_status=payment_status,
            notes=data.notes,
        )

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

        if data.paid_amount > 0:
            self.cash.record_cash_out(
                amount=data.paid_amount,
                entity_type="purchase_invoice",
                entity_id=invoice.purchase_invoice_id,
            )

        self.db.commit()
        self.db.refresh(invoice)
        return invoice
