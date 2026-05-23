from sqlalchemy.orm import Session
from decimal import Decimal
from app.repositories.payment_repo import PaymentRepository


class CashService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = PaymentRepository(db)

    def record_cash_in(self, amount: Decimal, entity_type: str, entity_id: int, description: str | None = None):
        self.repo.create_cash_transaction(
            transaction_type="cash_in",
            amount=amount,
            entity_type=entity_type,
            entity_id=entity_id,
            description=description,
        )

    def record_cash_out(self, amount: Decimal, entity_type: str, entity_id: int, description: str | None = None):
        self.repo.create_cash_transaction(
            transaction_type="cash_out",
            amount=amount,
            entity_type=entity_type,
            entity_id=entity_id,
            description=description,
        )
