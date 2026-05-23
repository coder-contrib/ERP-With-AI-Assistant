from sqlalchemy import Column, Integer, String, Text, Numeric, ForeignKey, DateTime
from sqlalchemy.sql import func
from app.database import Base


class Waste(Base):
    __tablename__ = "waste"

    waste_id = Column(Integer, primary_key=True)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    warehouse_id = Column(Integer, ForeignKey("warehouses.warehouse_id"), nullable=False)
    quantity = Column(Numeric(14, 4), nullable=False)
    waste_reason = Column(String(200))
    waste_date = Column(DateTime, server_default=func.now())
    notes = Column(Text)
