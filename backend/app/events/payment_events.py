from dataclasses import dataclass, field
from decimal import Decimal
from datetime import datetime


PAYMENT_RECEIVED = "payment.received"
PAYMENT_MADE = "payment.made"
EXPENSE_CREATED = "expense.created"


@dataclass
class PaymentReceivedData:
    payment_id: int
    customer_id: int
    amount: Decimal
    related_invoice_id: int | None = None
    timestamp: datetime = field(default_factory=datetime.utcnow)


@dataclass
class PaymentMadeData:
    payment_id: int
    supplier_id: int
    amount: Decimal
    related_purchase_invoice_id: int | None = None
    timestamp: datetime = field(default_factory=datetime.utcnow)


@dataclass
class ExpenseCreatedData:
    expense_id: int
    category: str
    amount: Decimal
    timestamp: datetime = field(default_factory=datetime.utcnow)
