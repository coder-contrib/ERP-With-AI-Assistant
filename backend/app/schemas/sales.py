from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime


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


class SalesReturnItemCreate(BaseModel):
    product_id: int
    returned_quantity: Decimal
    unit_price: Decimal
    total: Decimal


class SalesReturnCreate(BaseModel):
    refund_amount: Decimal = Decimal("0")
    notes: str | None = None
    items: list[SalesReturnItemCreate]


class SalesReturnItemResponse(BaseModel):
    item_id: int
    product_id: int
    returned_quantity: Decimal
    unit_price: Decimal
    total: Decimal

    class Config:
        from_attributes = True


class SalesReturnResponse(BaseModel):
    return_id: int
    original_invoice_id: int
    customer_id: int | None
    return_date: datetime | None
    returned_amount: Decimal
    refund_amount: Decimal
    notes: str | None

    class Config:
        from_attributes = True


class SalesItemResponse(BaseModel):
    item_id: int
    product_id: int
    sold_quantity: Decimal
    unit_type: str
    unit_price: Decimal
    cost_at_sale: Decimal
    discount: Decimal
    total_price: Decimal

    class Config:
        from_attributes = True


class SalesInvoiceResponse(BaseModel):
    invoice_id: int
    customer_id: int | None
    invoice_number: str
    invoice_type: str
    invoice_date: datetime | None
    total_amount: Decimal
    discount_amount: Decimal
    paid_amount: Decimal
    remaining_amount: Decimal
    payment_status: str
    warehouse_id: int

    class Config:
        from_attributes = True
