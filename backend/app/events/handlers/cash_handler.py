from app.events.event_bus import Event
from app.events.sale_events import SALE_CREATED
from app.events.purchase_events import PURCHASE_CREATED
from app.events.payment_events import PAYMENT_RECEIVED, PAYMENT_MADE, EXPENSE_CREATED
from sqlalchemy.orm import Session
from app.repositories.payment_repo import PaymentRepository


def handle_sale_cash(event: Event, db: Session):
    paid = event.data.get("paid_amount", 0)
    if paid > 0:
        repo = PaymentRepository(db)
        repo.create_cash_transaction(
            transaction_type="cash_in",
            amount=paid,
            entity_type="sales_invoice",
            entity_id=event.data["invoice_id"],
        )


def handle_purchase_cash(event: Event, db: Session):
    paid = event.data.get("paid_amount", 0)
    if paid > 0:
        repo = PaymentRepository(db)
        repo.create_cash_transaction(
            transaction_type="cash_out",
            amount=paid,
            entity_type="purchase_invoice",
            entity_id=event.data["purchase_invoice_id"],
        )


def handle_customer_payment_cash(event: Event, db: Session):
    repo = PaymentRepository(db)
    repo.create_cash_transaction(
        transaction_type="cash_in",
        amount=event.data["amount"],
        entity_type="customer_payment",
        entity_id=event.data["payment_id"],
    )


def handle_supplier_payment_cash(event: Event, db: Session):
    repo = PaymentRepository(db)
    repo.create_cash_transaction(
        transaction_type="cash_out",
        amount=event.data["amount"],
        entity_type="supplier_payment",
        entity_id=event.data["payment_id"],
    )


def handle_expense_cash(event: Event, db: Session):
    repo = PaymentRepository(db)
    repo.create_cash_transaction(
        transaction_type="cash_out",
        amount=event.data["amount"],
        entity_type="expense",
        entity_id=event.data["expense_id"],
    )
