from sqlalchemy import Column, Integer, String, Text, Numeric, ForeignKey, DateTime
from sqlalchemy.sql import func
from app.database import Base


class CustomerPayment(Base):
    __tablename__ = "customer_payments"

    payment_id = Column(Integer, primary_key=True)
    customer_id = Column(Integer, ForeignKey("customers.customer_id"), nullable=False)
    related_invoice_id = Column(Integer, ForeignKey("sales_invoices.invoice_id"))
    payment_amount = Column(Numeric(14, 2), nullable=False)
    payment_date = Column(DateTime, server_default=func.now())
    notes = Column(Text)


class SupplierPayment(Base):
    __tablename__ = "supplier_payments"

    payment_id = Column(Integer, primary_key=True)
    supplier_id = Column(Integer, ForeignKey("suppliers.supplier_id"), nullable=False)
    related_purchase_invoice_id = Column(Integer, ForeignKey("purchase_invoices.purchase_invoice_id"))
    payment_amount = Column(Numeric(14, 2), nullable=False)
    payment_date = Column(DateTime, server_default=func.now())
    notes = Column(Text)


class CashTransaction(Base):
    __tablename__ = "cash_transactions"

    transaction_id = Column(Integer, primary_key=True)
    transaction_type = Column(String(20), nullable=False)
    amount = Column(Numeric(14, 2), nullable=False)
    entity_type = Column(String(30), nullable=False)
    entity_id = Column(Integer)
    description = Column(Text)
    created_by = Column(Integer)
    transaction_date = Column(DateTime, server_default=func.now())
