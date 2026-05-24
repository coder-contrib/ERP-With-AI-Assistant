from pydantic import BaseModel
from decimal import Decimal
from datetime import date


class CustomerOpeningBalanceCreate(BaseModel):
    customer_id: int
    amount: Decimal
    balance_type: str = "receivable"
    balance_date: date | None = None
    notes: str | None = None


class SupplierOpeningBalanceCreate(BaseModel):
    supplier_id: int
    amount: Decimal
    balance_type: str = "payable"
    balance_date: date | None = None
    notes: str | None = None


class CashOpeningBalanceCreate(BaseModel):
    account_name: str = "cash"
    amount: Decimal
    balance_date: date | None = None
    notes: str | None = None


class OpeningBalanceResponse(BaseModel):
    id: int
    entity_type: str
    entity_id: int | None = None
    entity_name: str | None = None
    amount: Decimal
    balance_type: str
    notes: str | None = None

    class Config:
        from_attributes = True
