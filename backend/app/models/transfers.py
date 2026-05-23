from sqlalchemy import Column, Integer, Text, Numeric, ForeignKey, DateTime
from sqlalchemy.sql import func
from app.database import Base


class WarehouseTransfer(Base):
    __tablename__ = "warehouse_transfers"

    transfer_id = Column(Integer, primary_key=True)
    from_warehouse_id = Column(Integer, ForeignKey("warehouses.warehouse_id"), nullable=False)
    to_warehouse_id = Column(Integer, ForeignKey("warehouses.warehouse_id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    quantity = Column(Numeric(14, 4), nullable=False)
    transfer_date = Column(DateTime, server_default=func.now())
    notes = Column(Text)
