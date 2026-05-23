from dataclasses import dataclass, field
from decimal import Decimal
from datetime import datetime


PURCHASE_CREATED = "purchase.created"
PURCHASE_RETURNED = "purchase.returned"


@dataclass
class PurchaseCreatedData:
    purchase_invoice_id: int
    supplier_id: int
    warehouse_id: int
    total_amount: Decimal
    paid_amount: Decimal
    remaining_amount: Decimal
    items: list[dict] = field(default_factory=list)
    timestamp: datetime = field(default_factory=datetime.utcnow)


@dataclass
class PurchaseReturnedData:
    return_id: int
    original_purchase_invoice_id: int
    supplier_id: int
    returned_amount: Decimal
    items: list[dict] = field(default_factory=list)
    timestamp: datetime = field(default_factory=datetime.utcnow)
