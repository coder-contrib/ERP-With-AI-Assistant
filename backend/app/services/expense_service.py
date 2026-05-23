from sqlalchemy.orm import Session
from app.repositories.expense_repo import ExpenseRepository
from app.services.cash_service import CashService
from app.services.ledger_service import LedgerService
from app.schemas.expenses import ExpenseCreate
from app.models.expenses import Expense


class ExpenseService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = ExpenseRepository(db)
        self.cash = CashService(db)
        self.ledger = LedgerService(db)

    def list_all(self) -> list[Expense]:
        return self.repo.get_all()

    def create(self, data: ExpenseCreate) -> Expense:
        expense = self.repo.create(**data.model_dump())

        self.cash.record_cash_out(
            amount=data.amount,
            entity_type="expense",
            entity_id=expense.expense_id,
        )

        self.ledger.record_expense(
            expense_id=expense.expense_id,
            amount=data.amount,
            category=data.expense_category,
        )

        self.db.commit()
        self.db.refresh(expense)
        return expense
