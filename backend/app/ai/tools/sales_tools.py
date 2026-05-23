from sqlalchemy.orm import Session
from sqlalchemy import func, text
from decimal import Decimal
from datetime import date, datetime
from app.models.sales import SalesInvoice, SalesInvoiceItem
from app.models.customers import Customer
from app.models.products import Product


class SalesTools:
    """Tools for the Sales AI Agent.
    All data access goes through SQLAlchemy models (service layer).
    NEVER raw SQL or direct table access outside models.
    """

    def __init__(self, db: Session):
        self.db = db

    def get_today_sales(self) -> dict:
        today = date.today()
        result = self.db.query(
            func.count(SalesInvoice.invoice_id).label("count"),
            func.coalesce(func.sum(SalesInvoice.total_amount), 0).label("total"),
            func.coalesce(func.sum(SalesInvoice.paid_amount), 0).label("collected"),
        ).filter(func.date(SalesInvoice.invoice_date) == today).first()
        return {
            "date": str(today),
            "invoice_count": result.count,
            "total_sales": str(result.total),
            "cash_collected": str(result.collected),
        }

    def get_customer_info(self, customer_id: int) -> dict:
        customer = self.db.query(Customer).filter(Customer.customer_id == customer_id).first()
        if not customer:
            return {"error": "Customer not found"}
        return {
            "customer_id": customer.customer_id,
            "name": customer.customer_name,
            "phone": customer.phone_number,
            "balance": str(customer.current_balance),
            "credit_limit": str(customer.credit_limit),
            "payment_terms": customer.payment_terms,
        }

    def get_customer_history(self, customer_id: int, limit: int = 10) -> dict:
        invoices = self.db.query(SalesInvoice).filter(
            SalesInvoice.customer_id == customer_id
        ).order_by(SalesInvoice.invoice_date.desc()).limit(limit).all()
        return {
            "customer_id": customer_id,
            "invoices": [
                {
                    "invoice_number": inv.invoice_number,
                    "date": str(inv.invoice_date),
                    "total": str(inv.total_amount),
                    "status": inv.payment_status,
                }
                for inv in invoices
            ],
        }

    def get_top_selling_products(self, limit: int = 10, by: str = "quantity") -> dict:
        if by == "revenue":
            results = self.db.query(
                SalesInvoiceItem.product_id,
                Product.product_name,
                func.sum(SalesInvoiceItem.total_price).label("total_revenue"),
                func.sum(SalesInvoiceItem.sold_quantity).label("total_qty"),
            ).join(Product, Product.product_id == SalesInvoiceItem.product_id
            ).group_by(SalesInvoiceItem.product_id, Product.product_name
            ).order_by(func.sum(SalesInvoiceItem.total_price).desc()
            ).limit(limit).all()
        else:
            results = self.db.query(
                SalesInvoiceItem.product_id,
                Product.product_name,
                func.sum(SalesInvoiceItem.sold_quantity).label("total_qty"),
                func.sum(SalesInvoiceItem.total_price).label("total_revenue"),
            ).join(Product, Product.product_id == SalesInvoiceItem.product_id
            ).group_by(SalesInvoiceItem.product_id, Product.product_name
            ).order_by(func.sum(SalesInvoiceItem.sold_quantity).desc()
            ).limit(limit).all()

        return {
            "ranked_by": by,
            "products": [
                {
                    "product_id": r.product_id,
                    "name": r.product_name,
                    "total_quantity": str(r.total_qty),
                    "total_revenue": str(r.total_revenue),
                }
                for r in results
            ],
        }

    def get_sales_by_period(self, start_date: str, end_date: str) -> dict:
        results = self.db.query(
            func.date(SalesInvoice.invoice_date).label("day"),
            func.count(SalesInvoice.invoice_id).label("count"),
            func.sum(SalesInvoice.total_amount).label("total"),
        ).filter(
            func.date(SalesInvoice.invoice_date) >= start_date,
            func.date(SalesInvoice.invoice_date) <= end_date,
        ).group_by(func.date(SalesInvoice.invoice_date)
        ).order_by(func.date(SalesInvoice.invoice_date)).all()

        return {
            "period": {"start": start_date, "end": end_date},
            "days": [
                {"date": str(r.day), "count": r.count, "total": str(r.total)}
                for r in results
            ],
        }

    def get_unpaid_invoices(self, customer_id: int | None = None) -> dict:
        query = self.db.query(SalesInvoice).filter(
            SalesInvoice.payment_status.in_(["unpaid", "partial"])
        )
        if customer_id:
            query = query.filter(SalesInvoice.customer_id == customer_id)
        invoices = query.order_by(SalesInvoice.invoice_date.asc()).all()
        return {
            "count": len(invoices),
            "total_outstanding": str(sum(inv.remaining_amount for inv in invoices)),
            "invoices": [
                {
                    "invoice_number": inv.invoice_number,
                    "date": str(inv.invoice_date),
                    "total": str(inv.total_amount),
                    "remaining": str(inv.remaining_amount),
                    "status": inv.payment_status,
                }
                for inv in invoices
            ],
        }
