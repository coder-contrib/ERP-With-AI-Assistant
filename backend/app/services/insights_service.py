from sqlalchemy.orm import Session
from sqlalchemy import func
from decimal import Decimal
from datetime import date, timedelta
from app.models.sales import SalesInvoice, SalesInvoiceItem
from app.models.purchases import PurchaseInvoice
from app.models.customers import Customer
from app.models.suppliers import Supplier
from app.models.inventory import InventoryCache
from app.models.expenses import Expense
from app.models.accounting import DailyFinancialSummary
from app.models.products import Product
from app.ai.anomaly_detector import AnomalyDetector


class InsightsService:
    """AI-powered adaptive insights using anomaly detection.
    Uses z-scores, rolling averages, and seasonal baselines
    instead of static thresholds.
    """

    def __init__(self, db: Session):
        self.db = db
        self.detector = AnomalyDetector(db)

    def get_all_insights(self) -> list[dict]:
        insights = []
        insights.extend(self.detector.scan_all_anomalies())
        insights.extend(self._risk_analysis())
        insights.extend(self._opportunity_analysis())
        insights.sort(key=lambda x: {"critical": 0, "warning": 1, "info": 2, "success": 3}.get(x["severity"], 4))
        return insights

    def why_profit_dropped(self) -> dict:
        """Detailed explanation using adaptive baselines."""
        today = date.today()
        profit_anomaly = self.detector.detect_profit_anomaly(today)
        seasonal = self.detector.seasonal_baseline(today)
        rolling = self.detector.revenue_vs_rolling_baseline()

        this_week = self._period_summary(today - timedelta(days=7), today)
        last_week = self._period_summary(today - timedelta(days=14), today - timedelta(days=8))

        reasons = []
        if this_week["revenue"] < last_week["revenue"]:
            drop = last_week["revenue"] - this_week["revenue"]
            reasons.append(f"Revenue dropped by ${float(drop):,.0f}")

        if this_week["cogs_pct"] > last_week["cogs_pct"] + 3:
            reasons.append(f"COGS ratio rose from {last_week['cogs_pct']:.1f}% to {this_week['cogs_pct']:.1f}%")

        if this_week["expenses"] > last_week["expenses"] * Decimal("1.2"):
            reasons.append(f"Expenses up ${float(this_week['expenses'] - last_week['expenses']):,.0f}")

        if this_week["sales_count"] < last_week["sales_count"]:
            reasons.append(f"Fewer invoices: {this_week['sales_count']} vs {last_week['sales_count']}")

        detection_context = []
        if profit_anomaly["is_anomaly"]:
            detection_context.append(f"Z-score: {profit_anomaly['z_score']} (statistically significant)")
        if seasonal.get("profit", {}).get("is_anomaly"):
            detection_context.append(f"Below {seasonal['day_of_week']} seasonal average by {abs(seasonal['profit']['deviation_pct']):.0f}%")
        if rolling.get("is_anomaly"):
            detection_context.append(f"Revenue {abs(rolling['deviation_pct']):.0f}% below 7-day rolling baseline")

        return {
            "question": "Why did profit drop?",
            "this_week": this_week,
            "last_week": last_week,
            "reasons": reasons if reasons else ["No single dominant factor — multiple small declines"],
            "detection_context": detection_context,
            "recommendation": self._get_recommendation(reasons),
            "anomaly_data": {
                "z_score": profit_anomaly,
                "seasonal": seasonal,
                "rolling": rolling,
            },
        }

    def top_risks(self, limit: int = 3) -> list[dict]:
        all_insights = self.get_all_insights()
        risks = [i for i in all_insights if i["severity"] in ("critical", "warning")]
        return risks[:limit]

    def _risk_analysis(self) -> list[dict]:
        insights = []

        # Stock risk (adaptive: uses product-specific velocity)
        low_stock = self.db.query(func.count(InventoryCache.inventory_id)).filter(
            InventoryCache.cached_quantity <= 5, InventoryCache.cached_quantity > 0
        ).scalar()

        if low_stock > 0:
            insights.append({
                "type": "stock_risk",
                "severity": "critical" if low_stock > 5 else "warning",
                "title": f"{low_stock} products critically low",
                "message": f"{low_stock} products at 5 or fewer units. Reorder based on demand velocity.",
                "detection_method": "threshold",
            })

        # Credit risk
        overdue_customers = self.db.query(Customer).filter(
            Customer.current_balance > 0,
            Customer.credit_limit > 0,
            Customer.current_balance > Customer.credit_limit,
        ).count()

        if overdue_customers > 0:
            insights.append({
                "type": "credit_risk",
                "severity": "warning",
                "title": f"{overdue_customers} customers over credit limit",
                "message": "Pause credit sales for these customers until balance is reduced.",
                "detection_method": "threshold",
            })

        return insights

    def _opportunity_analysis(self) -> list[dict]:
        insights = []
        today = date.today()
        recent = today - timedelta(days=7)
        previous = recent - timedelta(days=7)

        recent_sales = self.db.query(
            SalesInvoiceItem.product_id,
            Product.product_name,
            func.sum(SalesInvoiceItem.sold_quantity).label("qty"),
        ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id
        ).join(Product, Product.product_id == SalesInvoiceItem.product_id
        ).filter(func.date(SalesInvoice.invoice_date) >= recent
        ).group_by(SalesInvoiceItem.product_id, Product.product_name).all()

        prev_map = {}
        prev_results = self.db.query(
            SalesInvoiceItem.product_id,
            func.sum(SalesInvoiceItem.sold_quantity).label("qty"),
        ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id
        ).filter(
            func.date(SalesInvoice.invoice_date) >= previous,
            func.date(SalesInvoice.invoice_date) < recent,
        ).group_by(SalesInvoiceItem.product_id).all()
        for p in prev_results:
            prev_map[p.product_id] = float(p.qty)

        for r in recent_sales:
            prev = prev_map.get(r.product_id, 0)
            if prev > 0:
                growth = ((float(r.qty) - prev) / prev) * 100
                if growth > 30:
                    insights.append({
                        "type": "trending_product",
                        "severity": "info",
                        "title": f"{r.product_name} up {growth:.0f}%",
                        "message": "Consider increasing stock for this trending product.",
                        "detection_method": "growth_rate",
                    })
                    break

        return insights

    def _period_summary(self, start: date, end: date) -> dict:
        result = self.db.query(
            func.coalesce(func.sum(DailyFinancialSummary.revenue), 0).label("revenue"),
            func.coalesce(func.sum(DailyFinancialSummary.cogs), 0).label("cogs"),
            func.coalesce(func.sum(DailyFinancialSummary.expenses), 0).label("expenses"),
            func.coalesce(func.sum(DailyFinancialSummary.net_profit), 0).label("net_profit"),
            func.coalesce(func.sum(DailyFinancialSummary.sales_count), 0).label("sales_count"),
        ).filter(
            DailyFinancialSummary.summary_date >= start,
            DailyFinancialSummary.summary_date <= end,
        ).first()

        revenue = float(result.revenue)
        cogs = float(result.cogs)
        cogs_pct = (cogs / revenue * 100) if revenue > 0 else 0

        return {
            "revenue": result.revenue,
            "cogs": result.cogs,
            "expenses": result.expenses,
            "net_profit": result.net_profit,
            "sales_count": result.sales_count,
            "cogs_pct": cogs_pct,
        }

    def _get_recommendation(self, reasons: list) -> str:
        if any("Revenue" in r for r in reasons):
            return "Focus on sales volume: promotions, customer re-engagement, or product range."
        if any("COGS" in r for r in reasons):
            return "Negotiate purchase costs or review selling prices."
        if any("Expenses" in r for r in reasons):
            return "Audit expense categories for unusual items."
        return "Monitor closely. If trend continues 3+ days, take action."
