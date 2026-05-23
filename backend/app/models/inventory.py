from sqlalchemy import Column, Integer, String, Text, Numeric, ForeignKey, DateTime
from sqlalchemy.sql import func
from app.database import Base


class InventoryTransaction(Base):
    __tablename__ = "inventory_transactions"

    transaction_id = Column(Integer, primary_key=True)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    warehouse_id = Column(Integer, ForeignKey("warehouses.warehouse_id"), nullable=False)
    transaction_type = Column(String(30), nullable=False)
    direction = Column(String(3), nullable=False)
    quantity = Column(Numeric(14, 4), nullable=False)
    unit_type = Column(String(20), nullable=False)
    cost_per_unit = Column(Numeric(12, 2), nullable=False, default=0)
    warehouse_from = Column(Integer, ForeignKey("warehouses.warehouse_id"))
    warehouse_to = Column(Integer, ForeignKey("warehouses.warehouse_id"))
    reference_type = Column(String(50))
    reference_id = Column(Integer)
    notes = Column(Text)
    created_by = Column(Integer)
    created_date = Column(DateTime, server_default=func.now())


class InventoryCache(Base):
    __tablename__ = "inventory_cache"

    inventory_id = Column(Integer, primary_key=True)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    warehouse_id = Column(Integer, ForeignKey("warehouses.warehouse_id"), nullable=False)
    cached_quantity = Column(Numeric(14, 4), nullable=False, default=0)
    cached_avg_cost = Column(Numeric(12, 2), nullable=False, default=0)
    cached_total_cost_in = Column(Numeric(16, 2), nullable=False, default=0)
    cached_total_qty_in = Column(Numeric(14, 4), nullable=False, default=0)
    last_updated = Column(DateTime, server_default=func.now())
