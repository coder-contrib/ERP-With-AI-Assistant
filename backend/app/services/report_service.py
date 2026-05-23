from sqlalchemy.orm import Session
from sqlalchemy import func, case, extract
from decimal import Decimal
from datetime import date, timedelta
from app.models.sales import SalesInvoice, SalesInvoiceItem
from app.models.purchases import PurchaseInvoice
from app.models.customers import Customer
from app.models.suppliers import Supplier
from app.models.products import Product
from app.models.inventory import InventoryCache, InventoryTransaction
from app.models.payments import CashTransaction
from app.models.expenses import Expense
from app.models.waste import Waste
from app.models.warehouses import Warehouse
from app.models.accounting import DailyFinancialSummary


class ReportService:
    def __init__(self, db: Session):
        self.db = db

    def daily_sales(self, start_date: date, end_date: date) -> list[dict]:
        results = self.db.query(
            func.date(SalesInvoice.invoice_date).label("day"),
            func.count(SalesInvoice.invoice_id).label("invoice_count"),
            func.coalesce(func.sum(SalesInvoice.total_amount), 0).label("total_sales"),
            func.coalesce(func.sum(SalesInvoice.discount_amount), 0).label("total_discount"),
            func.coalesce(func.sum(SalesInvoice.paid_amount), 0).label("cash_collected"),
            func.coalesce(func.sum(
                case((SalesInvoice.invoice_type == "credit", SalesInvoice.total_amount), else_=0)
            ), 0).label("credit_sales"),
        ).filter(
            func.date(SalesInvoice.invoice_date) >= start_date,
            func.date(SalesInvoice.invoice_date) <= end_date,
        ).group_by(func.date(SalesInvoice.invoice_date)
        ).order_by(func.date(SalesInvoice.invoice_date)).all()

        return [
            {
                "date": str(r.day),
                "invoice_count": r.invoice_count,
                "total_sales": str(r.total_sales),
                "total_discount": str(r.total_discount),
                "cash_collected": str(r.cash_collected),
                "credit_sales": str(r.credit_sales),
            }
            for r in results
        ]

    def monthly_profit(self, year: int) -> list[dict]:
        results = self.db.query(
            extract("month", DailyFinancialSummary.summary_date).label("month"),
            func.sum(DailyFinancialSummary.revenue).label("revenue"),
            func.sum(DailyFinancialSummary.cogs).label("cogs"),
            func.sum(DailyFinancialSummary.gross_profit).label("gross_profit"),
            func.sum(DailyFinancialSummary.expenses).label("expenses"),
            func.sum(DailyFinancialSummary.net_profit).label("net_profit"),
        ).filter(
            extract("year", DailyFinancialSummary.summary_date) == year,
        ).group_by(extract("month", DailyFinancialSummary.summary_date)
        ).order_by(extract("month", DailyFinancialSummary.summary_date)).all()

        return [
            {
                "month": f"{year}-{int(r.month):02d}",
                "revenue": str(r.revenue or 0),
                "cogs": str(r.cogs or 0),
                "gross_profit": str(r.gross_profit or 0),
                "gross_margin": str(
                    round((r.gross_profit / r.revenue * 100), 2)
                    if r.revenue and r.revenue > 0 else 0
                ),
                "expenses": str(r.expenses or 0),
                "net_profit": str(r.net_profit or 0),
            }
            for r in results
        ]

    def top_selling_products(self, start_date: date, end_date: date, limit: int = 20) -> list[dict]:
        results = self.db.query(
            SalesInvoiceItem.product_id,
            Product.product_name,
            func.sum(SalesInvoiceItem.sold_quantity).label("total_quantity"),
            func.sum(SalesInvoiceItem.total_price).label("total_revenue"),
        ).join(Product, Product.product_id == SalesInvoiceItem.product_id
        ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id
        ).filter(
            func.date(SalesInvoice.invoice_date) >= start_date,
            func.date(SalesInvoice.invoice_date) <= end_date,
        ).group_by(SalesInvoiceItem.product_id, Product.product_name
        ).order_by(func.sum(SalesInvoiceItem.total_price).desc()
        ).limit(limit).all()

        return [
            {
                "product_id": r.product_id,
                "product_name": r.product_name,
                "total_quantity": str(r.total_quantity),
                "total_revenue": str(r.total_revenue),
            }
            for r in results
        ]

    def inventory_valuation(self, warehouse_id: int | None = None) -> dict:
        query = self.db.query(
            InventoryCache.warehouse_id,
            Warehouse.warehouse_name,
            func.count(InventoryCache.product_id).label("product_count"),
            func.sum(InventoryCache.cached_quantity).label("total_quantity"),
            func.sum(InventoryCache.cached_quantity * InventoryCache.cached_avg_cost).label("total_value"),
        ).join(Warehouse, Warehouse.warehouse_id == InventoryCache.warehouse_id)
        if warehouse_id:
            query = query.filter(InventoryCache.warehouse_id == warehouse_id)
        results = query.group_by(InventoryCache.warehouse_id, Warehouse.warehouse_name).all()

        warehouses = [
            {
                "warehouse_id": r.warehouse_id,
                "warehouse_name": r.warehouse_name,
                "product_count": r.product_count,
                "total_quantity": str(r.total_quantity or 0),
                "total_value": str(r.total_value or 0),
            }
            for r in results
        ]
        return {
            "warehouses": warehouses,
            "grand_total_value": str(sum(r.total_value or 0 for r in results)),
        }

    def customer_balances(self) -> list[dict]:
        results = self.db.query(Customer).filter(
            Customer.current_balance > 0
        ).order_by(Customer.current_balance.desc()).all()

        return [
            {
                "customer_id": c.customer_id,
                "customer_name": c.customer_name,
                "current_balance": str(c.current_balance),
                "credit_limit": str(c.credit_limit),
                "over_limit": c.credit_limit > 0 and c.current_balance > c.credit_limit,
            }
            for c in results
        ]

    def supplier_balances(self) -> list[dict]:
        results = self.db.query(Supplier).filter(
            Supplier.current_balance > 0
        ).order_by(Supplier.current_balance.desc()).all()

        return [
            {
                "supplier_id": s.supplier_id,
                "supplier_name": s.supplier_name,
                "current_balance": str(s.current_balance),
                "payment_terms": s.payment_terms,
            }
            for s in results
        ]

    def cash_flow(self, start_date: date, end_date: date) -> dict:
        results = self.db.query(
            func.date(CashTransaction.transaction_date).label("day"),
            func.coalesce(func.sum(
                case((CashTransaction.transaction_type == "cash_in", CashTransaction.amount), else_=0)
            ), 0).label("cash_in"),
            func.coalesce(func.sum(
                case((CashTransaction.transaction_type == "cash_out", CashTransaction.amount), else_=0)
            ), 0).label("cash_out"),
        ).filter(
            func.date(CashTransaction.transaction_date) >= start_date,
            func.date(CashTransaction.transaction_date) <= end_date,
        ).group_by(func.date(CashTransaction.transaction_date)
        ).order_by(func.date(CashTransaction.transaction_date)).all()

        days = [
            {
                "date": str(r.day),
                "cash_in": str(r.cash_in),
                "cash_out": str(r.cash_out),
                "net": str(r.cash_in - r.cash_out),
            }
            for r in results
        ]
        return {
            "period": {"start": str(start_date), "end": str(end_date)},
            "days": days,
            "total_in": str(sum(r.cash_in for r in results)),
            "total_out": str(sum(r.cash_out for r in results)),
            "net_flow": str(sum(r.cash_in - r.cash_out for r in results)),
        }

    def waste_report(self, start_date: date, end_date: date) -> dict:
        results = self.db.query(
            Waste.product_id,
            Product.product_name,
            Waste.warehouse_id,
            func.sum(Waste.quantity).label("total_quantity"),
            Waste.waste_reason,
        ).join(Product, Product.product_id == Waste.product_id
        ).filter(
            func.date(Waste.waste_date) >= start_date,
            func.date(Waste.waste_date) <= end_date,
        ).group_by(
            Waste.product_id, Product.product_name, Waste.warehouse_id, Waste.waste_reason
        ).order_by(func.sum(Waste.quantity).desc()).all()

        items = [
            {
                "product_id": r.product_id,
                "product_name": r.product_name,
                "warehouse_id": r.warehouse_id,
                "total_quantity": str(r.total_quantity),
                "waste_reason": r.waste_reason,
            }
            for r in results
        ]
        return {
            "period": {"start": str(start_date), "end": str(end_date)},
            "items": items,
            "total_waste_entries": len(items),
        }

    def warehouse_stock(self, warehouse_id: int) -> dict:
        results = self.db.query(
            InventoryCache.product_id,
            Product.product_name,
            InventoryCache.cached_quantity,
            InventoryCache.cached_avg_cost,
        ).join(Product, Product.product_id == InventoryCache.product_id
        ).filter(
            InventoryCache.warehouse_id == warehouse_id,
            InventoryCache.cached_quantity > 0,
        ).order_by(Product.product_name).all()

        items = [
            {
                "product_id": r.product_id,
                "product_name": r.product_name,
                "quantity": str(r.cached_quantity),
                "avg_cost": str(r.cached_avg_cost),
                "total_value": str(r.cached_quantity * r.cached_avg_cost),
            }
            for r in results
        ]
        total_value = sum(r.cached_quantity * r.cached_avg_cost for r in results)
        return {
            "warehouse_id": warehouse_id,
            "product_count": len(items),
            "total_value": str(total_value),
            "items": items,
        }
