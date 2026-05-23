from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from decimal import Decimal
from app.database import get_db
from app.models.expenses import Expense
from app.models.payments import CashTransaction

router = APIRouter()


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
    notes: str | None

    class Config:
        from_attributes = True


@router.get("/", response_model=list[ExpenseResponse])
def list_expenses(db: Session = Depends(get_db)):
    return db.query(Expense).order_by(Expense.expense_date.desc()).all()


@router.post("/", response_model=ExpenseResponse, status_code=201)
def create_expense(data: ExpenseCreate, db: Session = Depends(get_db)):
    expense = Expense(**data.model_dump())
    db.add(expense)
    db.flush()

    cash_txn = CashTransaction(
        transaction_type="cash_out",
        amount=data.amount,
        entity_type="expense",
        entity_id=expense.expense_id,
    )
    db.add(cash_txn)
    db.commit()
    db.refresh(expense)
    return expense
