from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from decimal import Decimal
from app.database import get_db
from app.models.purchases import PurchaseInvoice, PurchaseInvoiceItem
from app.models.inventory import InventoryTransaction
from app.models.payments import CashTransaction

router = APIRouter()


class PurchaseItemCreate(BaseModel):
    product_id: int
    purchased_quantity: Decimal
    purchase_price: Decimal
    total_cost: Decimal


class PurchaseInvoiceCreate(BaseModel):
    supplier_id: int
    invoice_number: str
    warehouse_id: int
    unit_type: str = "meter"
    paid_amount: Decimal = Decimal("0")
    notes: str | None = None
    items: list[PurchaseItemCreate]


class PurchaseInvoiceResponse(BaseModel):
    purchase_invoice_id: int
    supplier_id: int
    invoice_number: str
    total_amount: Decimal
    paid_amount: Decimal
    remaining_amount: Decimal
    payment_status: str

    class Config:
        from_attributes = True


@router.get("/", response_model=list[PurchaseInvoiceResponse])
def list_purchases(db: Session = Depends(get_db)):
    return db.query(PurchaseInvoice).order_by(PurchaseInvoice.purchase_date.desc()).all()


@router.post("/", response_model=PurchaseInvoiceResponse, status_code=201)
def create_purchase(data: PurchaseInvoiceCreate, db: Session = Depends(get_db)):
    total_amount = sum(item.total_cost for item in data.items)
    remaining = total_amount - data.paid_amount
    payment_status = "paid" if remaining <= 0 else ("partial" if data.paid_amount > 0 else "unpaid")

    invoice = PurchaseInvoice(
        supplier_id=data.supplier_id,
        invoice_number=data.invoice_number,
        total_amount=total_amount,
        paid_amount=data.paid_amount,
        remaining_amount=max(remaining, Decimal("0")),
        payment_status=payment_status,
        notes=data.notes,
    )
    db.add(invoice)
    db.flush()

    for item_data in data.items:
        item = PurchaseInvoiceItem(purchase_invoice_id=invoice.purchase_invoice_id, **item_data.model_dump())
        db.add(item)

        inv_txn = InventoryTransaction(
            product_id=item_data.product_id,
            warehouse_id=data.warehouse_id,
            transaction_type="purchase",
            direction="IN",
            quantity=item_data.purchased_quantity,
            unit_type=data.unit_type,
            cost_per_unit=item_data.purchase_price,
            reference_type="purchase_invoice",
            reference_id=invoice.purchase_invoice_id,
        )
        db.add(inv_txn)

    if data.paid_amount > 0:
        cash_txn = CashTransaction(
            transaction_type="cash_out",
            amount=data.paid_amount,
            entity_type="purchase_invoice",
            entity_id=invoice.purchase_invoice_id,
        )
        db.add(cash_txn)

    db.commit()
    db.refresh(invoice)
    return invoice
