from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime


class ProductCreate(BaseModel):
    product_name: str
    category_id: int | None = None
    is_meter_based: bool = True
    allow_piece_sale: bool = False
    allow_carton_display: bool = True
    base_unit: str = "meter"
    purchase_cost_per_meter: Decimal = Decimal("0")
    selling_price: Decimal = Decimal("0")
    barcode: str | None = None
    notes: str | None = None


class ProductUpdate(BaseModel):
    product_name: str | None = None
    category_id: int | None = None
    is_meter_based: bool | None = None
    allow_piece_sale: bool | None = None
    allow_carton_display: bool | None = None
    base_unit: str | None = None
    purchase_cost_per_meter: Decimal | None = None
    selling_price: Decimal | None = None
    barcode: str | None = None
    active_status: bool | None = None
    notes: str | None = None


class ProductResponse(BaseModel):
    product_id: int
    product_name: str
    category_id: int | None
    is_meter_based: bool
    allow_piece_sale: bool
    allow_carton_display: bool
    base_unit: str
    purchase_cost_per_meter: Decimal
    selling_price: Decimal
    barcode: str | None
    active_status: bool
    created_date: datetime | None

    class Config:
        from_attributes = True


class ConversionCreate(BaseModel):
    from_unit: str
    to_unit: str
    factor: Decimal


class ConversionResponse(BaseModel):
    conversion_id: int
    product_id: int
    from_unit: str
    to_unit: str
    factor: Decimal

    class Config:
        from_attributes = True
