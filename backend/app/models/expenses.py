from sqlalchemy import Column, Integer, String, Text, Numeric, DateTime
from sqlalchemy.sql import func
from app.database import Base


class Expense(Base):
    __tablename__ = "expenses"

    expense_id = Column(Integer, primary_key=True)
    expense_category = Column(String(100), nullable=False)
    expense_name = Column(String(200), nullable=False)
    amount = Column(Numeric(14, 2), nullable=False)
    expense_date = Column(DateTime, server_default=func.now())
    notes = Column(Text)
