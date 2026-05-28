from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime


class StockResponse(BaseModel):
    product_id: int
    warehouse_id: int
    cached_quantity: Decimal
    cached_avg_cost: Decimal

    class Config:
        from_attributes = True


class InventoryTransactionCreate(BaseModel):
    product_id: int
    warehouse_id: int
    transaction_type: str = "opening_stock"
    direction: str = "in"
    quantity: Decimal
    unit_type: str = "meter"
    cost_per_unit: Decimal = Decimal("0")
    warehouse_from: int | None = None
    warehouse_to: int | None = None
    reference_type: str | None = None
    reference_id: int | None = None
    notes: str | None = None


class InventoryTransactionResponse(BaseModel):
    transaction_id: int
    product_id: int
    warehouse_id: int
    transaction_type: str
    direction: str
    quantity: Decimal
    unit_type: str
    cost_per_unit: Decimal
    reference_type: str | None = None
    reference_id: int | None = None
    notes: str | None = None
    created_date: datetime | None = None

    class Config:
        from_attributes = True
