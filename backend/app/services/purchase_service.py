from sqlalchemy.orm import Session
from decimal import Decimal
from app.database import transaction
from app.repositories.purchase_repo import PurchaseRepository
from app.repositories.supplier_repo import SupplierRepository
from app.services.inventory_service import InventoryService
from app.services.cash_service import CashService
from app.services.ledger_service import LedgerService
from app.core.validators import Validator
from app.events.event_bus import Event, get_event_bus
from app.events.purchase_events import PURCHASE_CREATED, PURCHASE_RETURNED
from app.schemas.purchases import PurchaseInvoiceCreate, PurchaseReturnCreate
from app.models.purchases import PurchaseInvoice, PurchaseReturn
from app.core.exceptions import NotFoundError, ValidationError


class PurchaseService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = PurchaseRepository(db)
        self.supplier_repo = SupplierRepository(db)
        self.inventory = InventoryService(db)
        self.cash = CashService(db)
        self.ledger = LedgerService(db)
        self.validator = Validator(db)
        self.event_bus = get_event_bus()

    def list_invoices(self) -> list[PurchaseInvoice]:
        return self.repo.get_all()

    def get_invoice(self, purchase_invoice_id: int) -> PurchaseInvoice:
        invoice = self.repo.get_by_id(purchase_invoice_id)
        if not invoice:
            raise NotFoundError("Purchase invoice not found")
        return invoice

    def create_invoice(self, data: PurchaseInvoiceCreate) -> PurchaseInvoice:
        with transaction(self.db):
            supplier = self.supplier_repo.get_by_id(data.supplier_id)
            if not supplier:
                raise NotFoundError("Supplier not found")

            for item_data in data.items:
                self.validator.validate_quantity(item_data.purchased_quantity, "Purchase quantity")
                self.validator.validate_positive_amount(item_data.purchase_price, "Purchase price")

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

            self.ledger.record_purchase(
                purchase_invoice_id=invoice.purchase_invoice_id,
                total_amount=total_amount,
                cash_paid=data.paid_amount,
                is_credit=(remaining > 0),
            )

            if remaining > 0:
                self.supplier_repo.update_balance(supplier, remaining)

        self.db.refresh(invoice)
        self.event_bus.publish(Event(
            event_type=PURCHASE_CREATED,
            data={
                "purchase_invoice_id": invoice.purchase_invoice_id,
                "supplier_id": data.supplier_id,
                "warehouse_id": data.warehouse_id,
                "total_amount": str(total_amount),
                "paid_amount": str(data.paid_amount),
                "remaining_amount": str(max(remaining, Decimal("0"))),
                "items": [item.model_dump() for item in data.items],
            },
        ))
        return invoice

    def process_return(self, purchase_invoice_id: int, data: PurchaseReturnCreate) -> PurchaseReturn:
        with transaction(self.db):
            invoice = self.repo.get_by_id(purchase_invoice_id)
            if not invoice:
                raise NotFoundError("Purchase invoice not found")

            if not data.items:
                raise ValidationError("At least one item is required for a return")

            invoice_items = self.repo.get_items_for_invoice(purchase_invoice_id)
            item_map = {item.product_id: item for item in invoice_items}

            for ret_item in data.items:
                orig = item_map.get(ret_item.product_id)
                if not orig:
                    raise ValidationError(f"Product {ret_item.product_id} not found in this invoice")
                if ret_item.returned_quantity > orig.purchased_quantity:
                    raise ValidationError(
                        f"Return quantity ({ret_item.returned_quantity}) exceeds purchased quantity ({orig.purchased_quantity})"
                    )

            returned_amount = sum(item.total for item in data.items)
            refund_amount = min(data.refund_amount, returned_amount)

            purchase_return = self.repo.create_return(
                original_purchase_invoice_id=purchase_invoice_id,
                supplier_id=invoice.supplier_id,
                returned_amount=returned_amount,
                notes=data.notes,
            )

            for ret_item in data.items:
                self.repo.create_return_item(
                    return_id=purchase_return.return_id,
                    product_id=ret_item.product_id,
                    returned_quantity=ret_item.returned_quantity,
                    unit_cost=ret_item.unit_cost,
                    total=ret_item.total,
                )
                self.inventory.record_purchase_return(
                    product_id=ret_item.product_id,
                    warehouse_id=data.warehouse_id,
                    quantity=ret_item.returned_quantity,
                    unit_type="meter",
                    cost_per_unit=ret_item.unit_cost,
                    reference_id=purchase_return.return_id,
                )

            if refund_amount > 0:
                self.cash.record_cash_in(
                    amount=refund_amount,
                    entity_type="purchase_return",
                    entity_id=purchase_return.return_id,
                )

            self.ledger.record_purchase_return(
                return_id=purchase_return.return_id,
                returned_amount=returned_amount,
                refund_amount=refund_amount,
            )

            supplier = self.supplier_repo.get_by_id(invoice.supplier_id)
            credit_reduction = returned_amount - refund_amount
            if credit_reduction > 0:
                self.supplier_repo.update_balance(supplier, -credit_reduction)

            invoice.total_amount -= returned_amount
            invoice.remaining_amount = max(invoice.remaining_amount - credit_reduction, Decimal("0"))
            invoice.paid_amount = max(invoice.paid_amount - refund_amount, Decimal("0"))
            if invoice.remaining_amount <= 0:
                invoice.payment_status = "paid"
            elif invoice.paid_amount > 0:
                invoice.payment_status = "partial"
            else:
                invoice.payment_status = "unpaid"
            self.db.flush()

        self.db.refresh(purchase_return)
        self.event_bus.publish(Event(
            event_type=PURCHASE_RETURNED,
            data={
                "return_id": purchase_return.return_id,
                "original_purchase_invoice_id": purchase_invoice_id,
                "supplier_id": invoice.supplier_id,
                "returned_amount": str(returned_amount),
                "refund_amount": str(refund_amount),
                "items": [item.model_dump() for item in data.items],
            },
        ))
        return purchase_return
