from pydantic import BaseModel
from decimal import Decimal


class TransferCreate(BaseModel):
    from_warehouse_id: int
    to_warehouse_id: int
    product_id: int
    quantity: Decimal
    unit_type: str = "meter"
    notes: str | None = None


class TransferResponse(BaseModel):
    transfer_id: int
    from_warehouse_id: int
    to_warehouse_id: int
    product_id: int
    quantity: Decimal

    class Config:
        from_attributes = True
