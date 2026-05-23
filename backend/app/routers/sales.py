from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from decimal import Decimal
from app.database import get_db
from app.models.sales import SalesInvoice, SalesInvoiceItem
from app.models.inventory import InventoryTransaction
from app.models.payments import CashTransaction

router = APIRouter()


class SalesItemCreate(BaseModel):
    product_id: int
    sold_quantity: Decimal
    unit_type: str
    conversion_factor_used: Decimal | None = None
    carton_count: Decimal | None = None
    piece_count: Decimal | None = None
    unit_price: Decimal
    cost_at_sale: Decimal = Decimal("0")
    discount: Decimal = Decimal("0")
    total_price: Decimal


class SalesInvoiceCreate(BaseModel):
    customer_id: int | None = None
    invoice_number: str
    invoice_type: str = "cash"
    warehouse_id: int
    discount_amount: Decimal = Decimal("0")
    paid_amount: Decimal = Decimal("0")
    warehouse_notes: str | None = None
    notes: str | None = None
    items: list[SalesItemCreate]


class SalesInvoiceResponse(BaseModel):
    invoice_id: int
    customer_id: int | None
    invoice_number: str
    invoice_type: str
    total_amount: Decimal
    discount_amount: Decimal
    paid_amount: Decimal
    remaining_amount: Decimal
    payment_status: str
    warehouse_id: int

    class Config:
        from_attributes = True


@router.get("/", response_model=list[SalesInvoiceResponse])
def list_sales(db: Session = Depends(get_db)):
    return db.query(SalesInvoice).order_by(SalesInvoice.invoice_date.desc()).all()


@router.get("/{invoice_id}", response_model=SalesInvoiceResponse)
def get_sale(invoice_id: int, db: Session = Depends(get_db)):
    invoice = db.query(SalesInvoice).filter(SalesInvoice.invoice_id == invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    return invoice


@router.post("/", response_model=SalesInvoiceResponse, status_code=201)
def create_sale(data: SalesInvoiceCreate, db: Session = Depends(get_db)):
    total_amount = sum(item.total_price for item in data.items)
    remaining = total_amount - data.discount_amount - data.paid_amount
    payment_status = "paid" if remaining <= 0 else ("partial" if data.paid_amount > 0 else "unpaid")

    invoice = SalesInvoice(
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
    db.add(invoice)
    db.flush()

    for item_data in data.items:
        item = SalesInvoiceItem(invoice_id=invoice.invoice_id, **item_data.model_dump())
        db.add(item)

        inv_txn = InventoryTransaction(
            product_id=item_data.product_id,
            warehouse_id=data.warehouse_id,
            transaction_type="sale",
            direction="OUT",
            quantity=item_data.sold_quantity,
            unit_type=item_data.unit_type,
            cost_per_unit=item_data.cost_at_sale,
            reference_type="sales_invoice",
            reference_id=invoice.invoice_id,
        )
        db.add(inv_txn)

    if data.paid_amount > 0:
        cash_txn = CashTransaction(
            transaction_type="cash_in",
            amount=data.paid_amount,
            entity_type="sales_invoice",
            entity_id=invoice.invoice_id,
        )
        db.add(cash_txn)

    db.commit()
    db.refresh(invoice)
    return invoice
