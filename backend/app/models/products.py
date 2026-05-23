from sqlalchemy import Column, Integer, String, Text, Boolean, Numeric, ForeignKey, DateTime
from sqlalchemy.sql import func
from app.database import Base


class Product(Base):
    __tablename__ = "products"

    product_id = Column(Integer, primary_key=True)
    product_name = Column(String(255), nullable=False)
    category_id = Column(Integer, ForeignKey("categories.category_id"))
    is_meter_based = Column(Boolean, nullable=False, default=True)
    allow_piece_sale = Column(Boolean, nullable=False, default=False)
    allow_carton_display = Column(Boolean, nullable=False, default=True)
    base_unit = Column(String(20), nullable=False, default="meter")
    purchase_cost_per_meter = Column(Numeric(12, 2), nullable=False, default=0)
    selling_price = Column(Numeric(12, 2), nullable=False, default=0)
    barcode = Column(String(100))
    product_image = Column(Text)
    active_status = Column(Boolean, nullable=False, default=True)
    created_date = Column(DateTime, server_default=func.now())
    notes = Column(Text)


class ProductUnitConversion(Base):
    __tablename__ = "product_unit_conversions"

    conversion_id = Column(Integer, primary_key=True)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    from_unit = Column(String(20), nullable=False)
    to_unit = Column(String(20), nullable=False)
    factor = Column(Numeric(10, 4), nullable=False)
