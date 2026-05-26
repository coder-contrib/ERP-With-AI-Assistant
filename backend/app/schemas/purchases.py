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


class PurchaseReturnItemCreate(BaseModel):
    product_id: int
    returned_quantity: Decimal
    unit_cost: Decimal
    total: Decimal


class PurchaseReturnCreate(BaseModel):
    items: list[PurchaseReturnItemCreate]
    warehouse_id: int = 1
    refund_amount: Decimal = Decimal("0")
    notes: str | None = None


class PurchaseReturnResponse(BaseModel):
    return_id: int
    original_purchase_invoice_id: int
    supplier_id: int
    returned_amount: Decimal
    return_date: datetime | None
    notes: str | None

    class Config:
        from_attributes = True
