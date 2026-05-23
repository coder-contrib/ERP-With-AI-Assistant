from sqlalchemy.orm import Session
from app.models.expenses import Expense


class ExpenseRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_all(self) -> list[Expense]:
        return self.db.query(Expense).order_by(Expense.expense_date.desc()).all()

    def get_by_id(self, expense_id: int) -> Expense | None:
        return self.db.query(Expense).filter(Expense.expense_id == expense_id).first()

    def create(self, **kwargs) -> Expense:
        expense = Expense(**kwargs)
        self.db.add(expense)
        self.db.flush()
        return expense
