from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.expenses import ExpenseCreate, ExpenseResponse
from app.services.expense_service import ExpenseService
from app.core.deps import require_permission
from app.models.users import User

router = APIRouter()


@router.get("/", response_model=list[ExpenseResponse])
def list_expenses(current_user: User = Depends(require_permission("expenses:read")), db: Session = Depends(get_db)):
    service = ExpenseService(db)
    return service.list_all()


@router.post("/", response_model=ExpenseResponse, status_code=201)
def create_expense(data: ExpenseCreate, current_user: User = Depends(require_permission("expenses:write")), db: Session = Depends(get_db)):
    service = ExpenseService(db)
    return service.create(data)
