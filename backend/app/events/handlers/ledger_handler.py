from app.events.event_bus import Event
from app.events.sale_events import SALE_CREATED
from app.events.purchase_events import PURCHASE_CREATED
from app.events.payment_events import PAYMENT_RECEIVED, PAYMENT_MADE, EXPENSE_CREATED
from decimal import Decimal
from sqlalchemy.orm import Session
from app.services.ledger_service import LedgerService


def handle_sale_ledger(event: Event, db: Session):
    ledger = LedgerService(db)
    data = event.data
    cogs = sum(Decimal(str(i["sold_quantity"])) * Decimal(str(i["cost_at_sale"])) for i in data.get("items", []))
    ledger.record_sale(
        invoice_id=data["invoice_id"],
        total_amount=Decimal(str(data["total_amount"])),
        cogs=cogs,
        cash_received=Decimal(str(data["paid_amount"])),
        is_credit=(data["invoice_type"] == "credit"),
    )


def handle_purchase_ledger(event: Event, db: Session):
    ledger = LedgerService(db)
    data = event.data
    ledger.record_purchase(
        purchase_invoice_id=data["purchase_invoice_id"],
        total_amount=Decimal(str(data["total_amount"])),
        cash_paid=Decimal(str(data["paid_amount"])),
        is_credit=(Decimal(str(data["remaining_amount"])) > 0),
    )


def handle_customer_payment_ledger(event: Event, db: Session):
    ledger = LedgerService(db)
    ledger.record_customer_payment(
        payment_id=event.data["payment_id"],
        amount=Decimal(str(event.data["amount"])),
    )


def handle_supplier_payment_ledger(event: Event, db: Session):
    ledger = LedgerService(db)
    ledger.record_supplier_payment(
        payment_id=event.data["payment_id"],
        amount=Decimal(str(event.data["amount"])),
    )


def handle_expense_ledger(event: Event, db: Session):
    ledger = LedgerService(db)
    ledger.record_expense(
        expense_id=event.data["expense_id"],
        amount=Decimal(str(event.data["amount"])),
        category=event.data["category"],
    )
