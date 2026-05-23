from sqlalchemy import Column, Integer, String, Text, Numeric, ForeignKey, DateTime
from sqlalchemy.sql import func
from app.database import Base


class PurchaseInvoice(Base):
    __tablename__ = "purchase_invoices"

    purchase_invoice_id = Column(Integer, primary_key=True)
    supplier_id = Column(Integer, ForeignKey("suppliers.supplier_id"), nullable=False)
    invoice_number = Column(String(50), nullable=False)
    purchase_date = Column(DateTime, server_default=func.now())
    total_amount = Column(Numeric(14, 2), nullable=False, default=0)
    paid_amount = Column(Numeric(14, 2), nullable=False, default=0)
    remaining_amount = Column(Numeric(14, 2), nullable=False, default=0)
    payment_status = Column(String(20), nullable=False, default="unpaid")
    notes = Column(Text)


class PurchaseInvoiceItem(Base):
    __tablename__ = "purchase_invoice_items"

    item_id = Column(Integer, primary_key=True)
    purchase_invoice_id = Column(Integer, ForeignKey("purchase_invoices.purchase_invoice_id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    purchased_quantity = Column(Numeric(14, 4), nullable=False)
    purchase_price = Column(Numeric(12, 2), nullable=False)
    total_cost = Column(Numeric(14, 2), nullable=False)


class PurchaseReturn(Base):
    __tablename__ = "purchase_returns"

    return_id = Column(Integer, primary_key=True)
    original_purchase_invoice_id = Column(Integer, ForeignKey("purchase_invoices.purchase_invoice_id"), nullable=False)
    supplier_id = Column(Integer, ForeignKey("suppliers.supplier_id"), nullable=False)
    return_date = Column(DateTime, server_default=func.now())
    returned_amount = Column(Numeric(14, 2), nullable=False, default=0)
    notes = Column(Text)


class PurchaseReturnItem(Base):
    __tablename__ = "purchase_return_items"

    item_id = Column(Integer, primary_key=True)
    return_id = Column(Integer, ForeignKey("purchase_returns.return_id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    returned_quantity = Column(Numeric(14, 4), nullable=False)
    unit_cost = Column(Numeric(12, 2), nullable=False)
    total = Column(Numeric(14, 2), nullable=False)
