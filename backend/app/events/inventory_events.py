from dataclasses import dataclass, field
from decimal import Decimal
from datetime import datetime


INVENTORY_IN = "inventory.in"
INVENTORY_OUT = "inventory.out"
INVENTORY_TRANSFER = "inventory.transfer"


@dataclass
class InventoryMovedData:
    product_id: int
    warehouse_id: int
    quantity: Decimal
    unit_type: str
    cost_per_unit: Decimal
    transaction_type: str
    reference_type: str | None = None
    reference_id: int | None = None
    timestamp: datetime = field(default_factory=datetime.utcnow)


@dataclass
class InventoryTransferData:
    transfer_id: int
    product_id: int
    from_warehouse_id: int
    to_warehouse_id: int
    quantity: Decimal
    unit_type: str
    timestamp: datetime = field(default_factory=datetime.utcnow)
