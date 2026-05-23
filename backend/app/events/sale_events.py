from dataclasses import dataclass, field
from decimal import Decimal
from datetime import datetime


SALE_CREATED = "sale.created"
SALE_RETURNED = "sale.returned"


@dataclass
class SaleCreatedData:
    invoice_id: int
    invoice_number: str
    invoice_type: str
    customer_id: int | None
    warehouse_id: int
    total_amount: Decimal
    discount_amount: Decimal
    paid_amount: Decimal
    remaining_amount: Decimal
    items: list[dict] = field(default_factory=list)
    timestamp: datetime = field(default_factory=datetime.utcnow)


@dataclass
class SaleReturnedData:
    return_id: int
    original_invoice_id: int
    customer_id: int | None
    returned_amount: Decimal
    refund_amount: Decimal
    items: list[dict] = field(default_factory=list)
    timestamp: datetime = field(default_factory=datetime.utcnow)
