from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, desc, text
from datetime import date, timedelta
from app.database import get_db
from app.schemas.expenses import (
    ExpenseCreate, ExpenseResponse, ExpenseSummary,
    ExpenseCategoryCreate, ExpenseCategoryResponse,
)
from app.services.expense_service import ExpenseService
from app.core.deps import require_permission, get_current_user
from app.models.users import User
from app.models.expenses import Expense, ExpenseCategory

router = APIRouter()


@router.get("/", response_model=list[ExpenseResponse])
def list_expenses(
    date_from: date | None = None,
    date_to: date | None = None,
    category: str | None = None,
    search: str | None = None,
    current_user: User = Depends(require_permission("expenses:read")),
    db: Session = Depends(get_db),
):
    query = db.query(Expense).order_by(desc(Expense.expense_date))

    if date_from:
        query = query.filter(func.date(Expense.expense_date) >= date_from)
    if date_to:
        query = query.filter(func.date(Expense.expense_date) <= date_to)
    if category:
        query = query.filter(Expense.expense_category == category)
    if search:
        query = query.filter(
            Expense.expense_name.ilike(f"%{search}%") |
            Expense.expense_category.ilike(f"%{search}%") |
            Expense.notes.ilike(f"%{search}%")
        )

    return query.all()


@router.post("/", response_model=ExpenseResponse, status_code=201)
def create_expense(
    data: ExpenseCreate,
    current_user: User = Depends(require_permission("expenses:write")),
    db: Session = Depends(get_db),
):
    service = ExpenseService(db)
    return service.create(data)


@router.get("/summary")
def get_expense_summary(
    current_user: User = Depends(require_permission("expenses:read")),
    db: Session = Depends(get_db),
):
    today = date.today()
    first_of_month = today.replace(day=1)

    total_today = db.query(
        func.coalesce(func.sum(Expense.amount), 0)
    ).filter(func.date(Expense.expense_date) == today).scalar()

    total_month = db.query(
        func.coalesce(func.sum(Expense.amount), 0)
    ).filter(
        func.date(Expense.expense_date) >= first_of_month,
        func.date(Expense.expense_date) <= today,
    ).scalar()

    highest = db.query(
        Expense.expense_category,
        func.sum(Expense.amount).label("total"),
    ).filter(
        func.date(Expense.expense_date) >= first_of_month,
    ).group_by(Expense.expense_category).order_by(desc("total")).first()

    expense_count = db.query(func.count(Expense.expense_id)).filter(
        func.date(Expense.expense_date) >= first_of_month,
    ).scalar()

    return {
        "total_today": str(total_today),
        "total_month": str(total_month),
        "highest_category": highest[0] if highest else None,
        "highest_category_amount": str(highest[1]) if highest else "0",
        "expense_count": expense_count or 0,
    }


@router.get("/categories")
def list_categories(
    current_user: User = Depends(require_permission("expenses:read")),
    db: Session = Depends(get_db),
):
    try:
        categories = db.query(ExpenseCategory).order_by(ExpenseCategory.name).all()
        return [{"category_id": c.category_id, "name": c.name, "description": c.description} for c in categories]
    except Exception:
        db.rollback()
        return [
            {"category_id": 0, "name": "Rent", "description": None},
            {"category_id": 0, "name": "Salaries", "description": None},
            {"category_id": 0, "name": "Electricity", "description": None},
            {"category_id": 0, "name": "Water", "description": None},
            {"category_id": 0, "name": "Internet", "description": None},
            {"category_id": 0, "name": "Transport", "description": None},
            {"category_id": 0, "name": "Maintenance", "description": None},
            {"category_id": 0, "name": "Marketing", "description": None},
            {"category_id": 0, "name": "Packaging", "description": None},
            {"category_id": 0, "name": "Miscellaneous", "description": None},
        ]


@router.post("/categories", status_code=201)
def create_category(
    data: ExpenseCategoryCreate,
    current_user: User = Depends(require_permission("expenses:write")),
    db: Session = Depends(get_db),
):
    try:
        category = ExpenseCategory(name=data.name, description=data.description)
        db.add(category)
        db.commit()
        db.refresh(category)
        return {"category_id": category.category_id, "name": category.name, "description": category.description}
    except Exception:
        db.rollback()
        return {"category_id": 0, "name": data.name, "description": data.description}


@router.delete("/{expense_id}", status_code=204)
def delete_expense(
    expense_id: int,
    current_user: User = Depends(require_permission("expenses:write")),
    db: Session = Depends(get_db),
):
    expense = db.query(Expense).filter(Expense.expense_id == expense_id).first()
    if expense:
        db.delete(expense)
        db.commit()
