from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime


class SupplierCreate(BaseModel):
    supplier_name: str
    phone_number: str | None = None
    address: str | None = None
    payment_terms: int = 0
    notes: str | None = None


class SupplierUpdate(BaseModel):
    supplier_name: str | None = None
    phone_number: str | None = None
    address: str | None = None
    payment_terms: int | None = None
    notes: str | None = None


class SupplierResponse(BaseModel):
    supplier_id: int
    supplier_name: str
    phone_number: str | None
    address: str | None
    current_balance: Decimal
    payment_terms: int
    last_payment_date: datetime | None
    notes: str | None

    class Config:
        from_attributes = True
