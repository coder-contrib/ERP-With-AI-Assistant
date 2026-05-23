from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime


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
    purchase_date: datetime | None
    total_amount: Decimal
    paid_amount: Decimal
    remaining_amount: Decimal
    payment_status: str

    class Config:
        from_attributes = True
