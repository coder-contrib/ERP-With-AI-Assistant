from sqlalchemy import Column, Integer, String, Text, Boolean, Numeric, ForeignKey, DateTime, Date
from sqlalchemy.sql import func
from app.database import Base


class Account(Base):
    __tablename__ = "accounts"

    account_id = Column(Integer, primary_key=True)
    account_code = Column(String(20), nullable=False, unique=True)
    account_name = Column(String(200), nullable=False)
    account_type = Column(String(20), nullable=False)
    parent_account_id = Column(Integer, ForeignKey("accounts.account_id"))
    is_system = Column(Boolean, nullable=False, default=False)
    active_status = Column(Boolean, nullable=False, default=True)
    notes = Column(Text)


class LedgerEntry(Base):
    __tablename__ = "ledger_entries"

    entry_id = Column(Integer, primary_key=True)
    entry_date = Column(DateTime, server_default=func.now())
    account_id = Column(Integer, ForeignKey("accounts.account_id"), nullable=False)
    debit = Column(Numeric(14, 2), nullable=False, default=0)
    credit = Column(Numeric(14, 2), nullable=False, default=0)
    entity_type = Column(String(30), nullable=False)
    entity_id = Column(Integer, nullable=False)
    description = Column(Text)
    created_by = Column(Integer)
    created_date = Column(DateTime, server_default=func.now())


class DailyFinancialSummary(Base):
    __tablename__ = "daily_financial_summary"

    summary_id = Column(Integer, primary_key=True)
    summary_date = Column(Date, nullable=False, unique=True)
    revenue = Column(Numeric(14, 2), nullable=False, default=0)
    cogs = Column(Numeric(14, 2), nullable=False, default=0)
    gross_profit = Column(Numeric(14, 2), nullable=False, default=0)
    expenses = Column(Numeric(14, 2), nullable=False, default=0)
    net_profit = Column(Numeric(14, 2), nullable=False, default=0)
    sales_count = Column(Integer, nullable=False, default=0)
    returns_amount = Column(Numeric(14, 2), nullable=False, default=0)
    last_updated = Column(DateTime, server_default=func.now())
