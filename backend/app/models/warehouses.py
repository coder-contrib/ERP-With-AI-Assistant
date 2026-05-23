from sqlalchemy import Column, Integer, String, Text
from app.database import Base


class Warehouse(Base):
    __tablename__ = "warehouses"

    warehouse_id = Column(Integer, primary_key=True)
    warehouse_name = Column(String(100), nullable=False)
    warehouse_location = Column(String(255))
    notes = Column(Text)
