from pydantic import BaseModel
from decimal import Decimal


class CustomerPaymentCreate(BaseModel):
    customer_id: int
    related_invoice_id: int | None = None
    payment_amount: Decimal
    notes: str | None = None


class SupplierPaymentCreate(BaseModel):
    supplier_id: int
    related_purchase_invoice_id: int | None = None
    payment_amount: Decimal
    notes: str | None = None


class PaymentResponse(BaseModel):
    payment_id: int
    payment_amount: Decimal
    notes: str | None

    class Config:
        from_attributes = True
