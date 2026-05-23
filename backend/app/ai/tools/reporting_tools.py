from sqlalchemy.orm import Session
from sqlalchemy import func
from decimal import Decimal
from datetime import date, timedelta
from app.models.sales import SalesInvoice, SalesInvoiceItem
from app.models.inventory import InventoryCache, InventoryTransaction
from app.models.products import Product
from app.models.customers import Customer
from app.models.accounting import DailyFinancialSummary


class ReportingTools:
    """AI reporting tools for predictions and analysis."""

    def __init__(self, db: Session):
        self.db = db

    def demand_forecast(self, product_id: int, days_back: int = 30) -> dict:
        """Predict future demand based on recent sales velocity."""
        cutoff = date.today() - timedelta(days=days_back)
        total_sold = self.db.query(
            func.coalesce(func.sum(SalesInvoiceItem.sold_quantity), 0)
        ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id
        ).filter(
            SalesInvoiceItem.product_id == product_id,
            func.date(SalesInvoice.invoice_date) >= cutoff,
        ).scalar()

        daily_avg = float(total_sold) / days_back if days_back > 0 else 0

        current_stock = self.db.query(
            func.coalesce(func.sum(InventoryCache.cached_quantity), 0)
        ).filter(InventoryCache.product_id == product_id).scalar()

        days_until_stockout = int(float(current_stock) / daily_avg) if daily_avg > 0 else 999

        product = self.db.query(Product).filter(Product.product_id == product_id).first()

        return {
            "product_id": product_id,
            "product_name": product.product_name if product else "Unknown",
            "period_days": days_back,
            "total_sold": str(total_sold),
            "daily_average": round(daily_avg, 4),
            "weekly_forecast": round(daily_avg * 7, 4),
            "monthly_forecast": round(daily_avg * 30, 4),
            "current_stock": str(current_stock),
            "days_until_stockout": days_until_stockout,
            "reorder_urgent": days_until_stockout <= 7,
        }

    def low_stock_prediction(self, days_ahead: int = 7) -> dict:
        """Predict which products will run out within X days."""
        cutoff = date.today() - timedelta(days=30)

        products_with_sales = self.db.query(
            SalesInvoiceItem.product_id,
            Product.product_name,
            func.sum(SalesInvoiceItem.sold_quantity).label("total_sold_30d"),
        ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id
        ).join(Product, Product.product_id == SalesInvoiceItem.product_id
        ).filter(func.date(SalesInvoice.invoice_date) >= cutoff
        ).group_by(SalesInvoiceItem.product_id, Product.product_name).all()

        at_risk = []
        for p in products_with_sales:
            daily_avg = float(p.total_sold_30d) / 30
            projected_demand = daily_avg * days_ahead

            current_stock = self.db.query(
                func.coalesce(func.sum(InventoryCache.cached_quantity), 0)
            ).filter(InventoryCache.product_id == p.product_id).scalar()

            if float(current_stock) <= projected_demand:
                at_risk.append({
                    "product_id": p.product_id,
                    "product_name": p.product_name,
                    "current_stock": str(current_stock),
                    "projected_demand": round(projected_demand, 2),
                    "daily_average": round(daily_avg, 4),
                    "days_left": int(float(current_stock) / daily_avg) if daily_avg > 0 else 999,
                })

        at_risk.sort(key=lambda x: x["days_left"])
        return {
            "forecast_days": days_ahead,
            "at_risk_count": len(at_risk),
            "products": at_risk,
        }

    def best_selling_prediction(self, days_back: int = 30) -> dict:
        """Identify trending products based on sales acceleration."""
        recent_cutoff = date.today() - timedelta(days=days_back)
        previous_cutoff = recent_cutoff - timedelta(days=days_back)

        recent = self.db.query(
            SalesInvoiceItem.product_id,
            Product.product_name,
            func.sum(SalesInvoiceItem.sold_quantity).label("recent_qty"),
            func.sum(SalesInvoiceItem.total_price).label("recent_revenue"),
        ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id
        ).join(Product, Product.product_id == SalesInvoiceItem.product_id
        ).filter(func.date(SalesInvoice.invoice_date) >= recent_cutoff
        ).group_by(SalesInvoiceItem.product_id, Product.product_name).all()

        previous = {}
        prev_results = self.db.query(
            SalesInvoiceItem.product_id,
            func.sum(SalesInvoiceItem.sold_quantity).label("prev_qty"),
        ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id
        ).filter(
            func.date(SalesInvoice.invoice_date) >= previous_cutoff,
            func.date(SalesInvoice.invoice_date) < recent_cutoff,
        ).group_by(SalesInvoiceItem.product_id).all()
        for p in prev_results:
            previous[p.product_id] = float(p.prev_qty)

        trending = []
        for r in recent:
            prev_qty = previous.get(r.product_id, 0)
            recent_qty = float(r.recent_qty)
            growth = ((recent_qty - prev_qty) / prev_qty * 100) if prev_qty > 0 else 100.0
            trending.append({
                "product_id": r.product_id,
                "product_name": r.product_name,
                "recent_quantity": str(r.recent_qty),
                "previous_quantity": str(prev_qty),
                "growth_percent": round(growth, 1),
                "recent_revenue": str(r.recent_revenue),
            })

        trending.sort(key=lambda x: x["growth_percent"], reverse=True)
        return {
            "period_days": days_back,
            "trending_up": [t for t in trending if t["growth_percent"] > 0][:10],
            "trending_down": [t for t in trending if t["growth_percent"] < 0][:10],
        }

    def customer_behavior_analysis(self, customer_id: int) -> dict:
        """Analyze customer purchasing patterns."""
        customer = self.db.query(Customer).filter(Customer.customer_id == customer_id).first()
        if not customer:
            return {"error": "Customer not found"}

        invoices = self.db.query(SalesInvoice).filter(
            SalesInvoice.customer_id == customer_id
        ).order_by(SalesInvoice.invoice_date.desc()).all()

        if not invoices:
            return {
                "customer_id": customer_id,
                "customer_name": customer.customer_name,
                "total_invoices": 0,
                "analysis": "No purchase history",
            }

        total_spent = sum(inv.total_amount for inv in invoices)
        avg_invoice = total_spent / len(invoices) if invoices else 0

        last_30 = [inv for inv in invoices if (date.today() - inv.invoice_date.date()).days <= 30]
        last_90 = [inv for inv in invoices if (date.today() - inv.invoice_date.date()).days <= 90]

        days_since_last = (date.today() - invoices[0].invoice_date.date()).days if invoices else 999

        top_products = self.db.query(
            SalesInvoiceItem.product_id,
            Product.product_name,
            func.sum(SalesInvoiceItem.sold_quantity).label("qty"),
            func.sum(SalesInvoiceItem.total_price).label("total"),
        ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id
        ).join(Product, Product.product_id == SalesInvoiceItem.product_id
        ).filter(SalesInvoice.customer_id == customer_id
        ).group_by(SalesInvoiceItem.product_id, Product.product_name
        ).order_by(func.sum(SalesInvoiceItem.total_price).desc()).limit(5).all()

        return {
            "customer_id": customer_id,
            "customer_name": customer.customer_name,
            "total_invoices": len(invoices),
            "total_spent": str(total_spent),
            "average_invoice_value": str(round(avg_invoice, 2)),
            "invoices_last_30_days": len(last_30),
            "invoices_last_90_days": len(last_90),
            "days_since_last_purchase": days_since_last,
            "current_balance": str(customer.current_balance),
            "payment_reliability": "good" if customer.current_balance <= 0 else (
                "at_risk" if customer.credit_limit > 0 and customer.current_balance > customer.credit_limit * Decimal("0.8") else "moderate"
            ),
            "top_products": [
                {"name": p.product_name, "quantity": str(p.qty), "total": str(p.total)}
                for p in top_products
            ],
        }

    def profit_analysis(self, start_date: str, end_date: str) -> dict:
        """Analyze profit trends and identify issues."""
        results = self.db.query(DailyFinancialSummary).filter(
            DailyFinancialSummary.summary_date >= start_date,
            DailyFinancialSummary.summary_date <= end_date,
        ).order_by(DailyFinancialSummary.summary_date).all()

        if not results:
            return {"error": "No data for this period"}

        total_revenue = sum(r.revenue for r in results)
        total_cogs = sum(r.cogs for r in results)
        total_expenses = sum(r.expenses for r in results)
        total_profit = sum(r.net_profit for r in results)

        mid = len(results) // 2
        first_half_profit = sum(r.net_profit for r in results[:mid]) if mid > 0 else 0
        second_half_profit = sum(r.net_profit for r in results[mid:]) if mid > 0 else 0

        trend = "stable"
        if second_half_profit > first_half_profit * Decimal("1.1"):
            trend = "increasing"
        elif second_half_profit < first_half_profit * Decimal("0.9"):
            trend = "decreasing"

        gross_margin = (total_revenue - total_cogs) / total_revenue * 100 if total_revenue > 0 else 0
        net_margin = total_profit / total_revenue * 100 if total_revenue > 0 else 0

        issues = []
        if gross_margin < 25:
            issues.append("Gross margin below 25% — check purchase costs")
        if net_margin < 10:
            issues.append("Net margin below 10% — review expenses")
        if total_expenses > total_revenue * Decimal("0.3"):
            issues.append("Expenses exceed 30% of revenue")
        if trend == "decreasing":
            issues.append("Profit trending downward in second half of period")

        return {
            "period": {"start": start_date, "end": end_date},
            "total_revenue": str(total_revenue),
            "total_cogs": str(total_cogs),
            "total_expenses": str(total_expenses),
            "net_profit": str(total_profit),
            "gross_margin_percent": round(float(gross_margin), 2),
            "net_margin_percent": round(float(net_margin), 2),
            "profit_trend": trend,
            "issues": issues,
            "days_analyzed": len(results),
        }
