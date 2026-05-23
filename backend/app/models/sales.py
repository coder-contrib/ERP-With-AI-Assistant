from sqlalchemy import Column, Integer, String, Text, Numeric, ForeignKey, DateTime
from sqlalchemy.sql import func
from app.database import Base


class SalesInvoice(Base):
    __tablename__ = "sales_invoices"

    invoice_id = Column(Integer, primary_key=True)
    customer_id = Column(Integer, ForeignKey("customers.customer_id"))
    invoice_number = Column(String(50), nullable=False, unique=True)
    invoice_type = Column(String(10), nullable=False, default="cash")
    invoice_date = Column(DateTime, server_default=func.now())
    total_amount = Column(Numeric(14, 2), nullable=False, default=0)
    discount_amount = Column(Numeric(14, 2), nullable=False, default=0)
    paid_amount = Column(Numeric(14, 2), nullable=False, default=0)
    remaining_amount = Column(Numeric(14, 2), nullable=False, default=0)
    payment_status = Column(String(20), nullable=False, default="unpaid")
    warehouse_id = Column(Integer, ForeignKey("warehouses.warehouse_id"), nullable=False)
    warehouse_notes = Column(Text)
    notes = Column(Text)


class SalesInvoiceItem(Base):
    __tablename__ = "sales_invoice_items"

    item_id = Column(Integer, primary_key=True)
    invoice_id = Column(Integer, ForeignKey("sales_invoices.invoice_id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    sold_quantity = Column(Numeric(14, 4), nullable=False)
    unit_type = Column(String(20), nullable=False)
    conversion_factor_used = Column(Numeric(10, 4))
    carton_count = Column(Numeric(10, 2))
    piece_count = Column(Numeric(10, 2))
    unit_price = Column(Numeric(12, 2), nullable=False)
    cost_at_sale = Column(Numeric(12, 2), nullable=False, default=0)
    discount = Column(Numeric(12, 2), nullable=False, default=0)
    total_price = Column(Numeric(14, 2), nullable=False)
    notes = Column(Text)


class SalesReturn(Base):
    __tablename__ = "sales_returns"

    return_id = Column(Integer, primary_key=True)
    original_invoice_id = Column(Integer, ForeignKey("sales_invoices.invoice_id"), nullable=False)
    customer_id = Column(Integer, ForeignKey("customers.customer_id"))
    return_date = Column(DateTime, server_default=func.now())
    returned_amount = Column(Numeric(14, 2), nullable=False, default=0)
    refund_amount = Column(Numeric(14, 2), nullable=False, default=0)
    notes = Column(Text)


class SalesReturnItem(Base):
    __tablename__ = "sales_return_items"

    item_id = Column(Integer, primary_key=True)
    return_id = Column(Integer, ForeignKey("sales_returns.return_id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.product_id"), nullable=False)
    returned_quantity = Column(Numeric(14, 4), nullable=False)
    unit_price = Column(Numeric(12, 2), nullable=False)
    total = Column(Numeric(14, 2), nullable=False)
