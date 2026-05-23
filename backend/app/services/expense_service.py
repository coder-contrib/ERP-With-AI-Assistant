from sqlalchemy.orm import Session
from app.database import transaction
from app.repositories.expense_repo import ExpenseRepository
from app.services.cash_service import CashService
from app.services.ledger_service import LedgerService
from app.core.validators import Validator
from app.events.event_bus import Event, get_event_bus
from app.events.payment_events import EXPENSE_CREATED
from app.schemas.expenses import ExpenseCreate
from app.models.expenses import Expense


class ExpenseService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = ExpenseRepository(db)
        self.cash = CashService(db)
        self.ledger = LedgerService(db)
        self.validator = Validator(db)
        self.event_bus = get_event_bus()

    def list_all(self) -> list[Expense]:
        return self.repo.get_all()

    def create(self, data: ExpenseCreate) -> Expense:
        with transaction(self.db):
            self.validator.validate_positive_amount(data.amount, "Expense amount")

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

        self.db.refresh(expense)
        self.event_bus.publish(Event(
            event_type=EXPENSE_CREATED,
            data={
                "expense_id": expense.expense_id,
                "category": data.expense_category,
                "amount": str(data.amount),
            },
        ))
        return expense
