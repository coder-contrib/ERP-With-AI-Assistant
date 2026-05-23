from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime


class CustomerCreate(BaseModel):
    customer_name: str
    phone_number: str | None = None
    address: str | None = None
    credit_limit: Decimal = Decimal("0")
    payment_terms: int = 0
    notes: str | None = None


class CustomerUpdate(BaseModel):
    customer_name: str | None = None
    phone_number: str | None = None
    address: str | None = None
    credit_limit: Decimal | None = None
    payment_terms: int | None = None
    notes: str | None = None


class CustomerResponse(BaseModel):
    customer_id: int
    customer_name: str
    phone_number: str | None
    address: str | None
    current_balance: Decimal
    credit_limit: Decimal
    payment_terms: int
    notes: str | None
    created_date: datetime | None

    class Config:
        from_attributes = True
