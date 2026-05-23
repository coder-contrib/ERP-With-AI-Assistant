from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime


class ExpenseCreate(BaseModel):
    expense_category: str
    expense_name: str
    amount: Decimal
    notes: str | None = None


class ExpenseResponse(BaseModel):
    expense_id: int
    expense_category: str
    expense_name: str
    amount: Decimal
    expense_date: datetime | None
    notes: str | None

    class Config:
        from_attributes = True
