from sqlalchemy import Column, Integer, String, Text, Numeric, DateTime
from sqlalchemy.sql import func
from app.database import Base


class Expense(Base):
    __tablename__ = "expenses"

    expense_id = Column(Integer, primary_key=True)
    expense_category = Column(String(100), nullable=False)
    expense_name = Column(String(200), nullable=False)
    amount = Column(Numeric(14, 2), nullable=False)
    payment_method = Column(String(30), server_default="cash")
    paid_by = Column(String(100))
    receipt_number = Column(String(50))
    expense_date = Column(DateTime, server_default=func.now())
    notes = Column(Text)
    created_by = Column(Integer)


class ExpenseCategory(Base):
    __tablename__ = "expense_categories"

    category_id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False, unique=True)
    description = Column(Text)
