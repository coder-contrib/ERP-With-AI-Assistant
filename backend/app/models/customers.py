from sqlalchemy import Column, Integer, String, Text, Numeric, DateTime
from sqlalchemy.sql import func
from app.database import Base


class Customer(Base):
    __tablename__ = "customers"

    customer_id = Column(Integer, primary_key=True)
    customer_name = Column(String(200), nullable=False)
    phone_number = Column(String(30))
    address = Column(Text)
    current_balance = Column(Numeric(14, 2), nullable=False, default=0)
    credit_limit = Column(Numeric(14, 2), nullable=False, default=0)
    payment_terms = Column(Integer, nullable=False, default=0)
    notes = Column(Text)
    created_date = Column(DateTime, server_default=func.now())
