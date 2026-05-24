from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime, date


class ExpenseCreate(BaseModel):
    expense_category: str
    expense_name: str
    amount: Decimal
    payment_method: str = "cash"
    paid_by: str | None = None
    receipt_number: str | None = None
    expense_date: date | None = None
    notes: str | None = None


class ExpenseResponse(BaseModel):
    expense_id: int
    expense_category: str
    expense_name: str
    amount: Decimal
    payment_method: str | None = None
    paid_by: str | None = None
    receipt_number: str | None = None
    expense_date: datetime | None
    notes: str | None

    class Config:
        from_attributes = True


class ExpenseCategoryCreate(BaseModel):
    name: str
    description: str | None = None


class ExpenseCategoryResponse(BaseModel):
    category_id: int
    name: str
    description: str | None = None

    class Config:
        from_attributes = True


class ExpenseSummary(BaseModel):
    total_today: Decimal
    total_month: Decimal
    highest_category: str | None
    highest_category_amount: Decimal
    expense_count: int
