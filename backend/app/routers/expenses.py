from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.expenses import ExpenseCreate, ExpenseResponse
from app.repositories.expense_repo import ExpenseRepository
from app.services.cash_service import CashService

router = APIRouter()


@router.get("/", response_model=list[ExpenseResponse])
def list_expenses(db: Session = Depends(get_db)):
    repo = ExpenseRepository(db)
    return repo.get_all()


@router.post("/", response_model=ExpenseResponse, status_code=201)
def create_expense(data: ExpenseCreate, db: Session = Depends(get_db)):
    repo = ExpenseRepository(db)
    cash = CashService(db)

    expense = repo.create(**data.model_dump())
    cash.record_cash_out(
        amount=data.amount,
        entity_type="expense",
        entity_id=expense.expense_id,
    )

    db.commit()
    db.refresh(expense)
    return expense
