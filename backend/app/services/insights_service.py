from sqlalchemy.orm import Session
from sqlalchemy import func, text
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


class InsightsService:
    """AI-powered auto-insights for the dashboard.
    Analyzes ERP data and generates human-readable explanations.
    """

    def __init__(self, db: Session):
        self.db = db

    def get_all_insights(self) -> list[dict]:
        insights = []
        insights.extend(self.profit_analysis())
        insights.extend(self.risk_analysis())
        insights.extend(self.opportunity_analysis())
        insights.sort(key=lambda x: {"critical": 0, "warning": 1, "info": 2, "success": 3}.get(x["severity"], 4))
        return insights

    def profit_analysis(self) -> list[dict]:
        """Analyze why profit changed and generate explanations."""
        insights = []
        today = date.today()

        # Compare this week vs last week
        this_week_start = today - timedelta(days=7)
        last_week_start = this_week_start - timedelta(days=7)

        this_week = self._period_summary(this_week_start, today)
        last_week = self._period_summary(last_week_start, this_week_start - timedelta(days=1))

        if last_week["revenue"] > 0 and this_week["revenue"] > 0:
            revenue_change = ((this_week["revenue"] - last_week["revenue"]) / last_week["revenue"]) * 100
            profit_change = 0
            if last_week["net_profit"] != 0:
                profit_change = ((this_week["net_profit"] - last_week["net_profit"]) / abs(last_week["net_profit"])) * 100

            if profit_change < -10:
                reasons = self._explain_profit_drop(this_week, last_week)
                insights.append({
                    "type": "profit_drop",
                    "severity": "critical",
                    "title": f"Profit dropped {abs(profit_change):.0f}% this week",
                    "message": reasons,
                    "metric": {"current": str(this_week["net_profit"]), "previous": str(last_week["net_profit"]), "change_pct": round(profit_change, 1)},
                })
            elif profit_change > 10:
                insights.append({
                    "type": "profit_growth",
                    "severity": "success",
                    "title": f"Profit grew {profit_change:.0f}% this week",
                    "message": f"Revenue: ${this_week['revenue']:,.0f} (was ${last_week['revenue']:,.0f}). Keep momentum going.",
                    "metric": {"current": str(this_week["net_profit"]), "previous": str(last_week["net_profit"]), "change_pct": round(profit_change, 1)},
                })

            if this_week["gross_margin"] < 25:
                insights.append({
                    "type": "low_margin",
                    "severity": "warning",
                    "title": f"Gross margin at {this_week['gross_margin']:.1f}%",
                    "message": "Margin below 25%. Review purchase costs or increase selling prices.",
                    "metric": {"value": round(this_week["gross_margin"], 1)},
                })

        return insights

    def risk_analysis(self) -> list[dict]:
        """Identify top business risks."""
        insights = []

        # 1. Cash flow risk
        total_receivables = self.db.query(
            func.coalesce(func.sum(Customer.current_balance), 0)
        ).filter(Customer.current_balance > 0).scalar()

        total_payables = self.db.query(
            func.coalesce(func.sum(Supplier.current_balance), 0)
        ).filter(Supplier.current_balance > 0).scalar()

        if total_payables > 0 and total_receivables > total_payables * 2:
            insights.append({
                "type": "cash_flow_risk",
                "severity": "warning",
                "title": "High receivables vs payables",
                "message": f"Receivables (${total_receivables:,.0f}) are {total_receivables/total_payables:.1f}x payables (${total_payables:,.0f}). Follow up on collections.",
                "metric": {"receivables": str(total_receivables), "payables": str(total_payables)},
            })

        # 2. Stock risk
        low_stock = self.db.query(func.count(InventoryCache.inventory_id)).filter(
            InventoryCache.cached_quantity <= 5, InventoryCache.cached_quantity > 0
        ).scalar()

        out_of_stock = self.db.query(func.count(InventoryCache.inventory_id)).filter(
            InventoryCache.cached_quantity <= 0
        ).scalar()

        if low_stock > 0:
            insights.append({
                "type": "stock_risk",
                "severity": "critical" if low_stock > 5 else "warning",
                "title": f"{low_stock} products critically low",
                "message": f"{low_stock} products have 5 or fewer units. {out_of_stock} are completely out of stock. Reorder immediately.",
                "metric": {"low_stock": low_stock, "out_of_stock": out_of_stock},
            })

        # 3. Overdue customer payments
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
                "message": "These customers have exceeded their credit limit. Consider pausing credit sales until they pay.",
                "metric": {"count": overdue_customers},
            })

        # 4. Expense spike
        today = date.today()
        this_week_expenses = self.db.query(
            func.coalesce(func.sum(Expense.amount), 0)
        ).filter(func.date(Expense.expense_date) >= today - timedelta(days=7)).scalar()

        last_week_expenses = self.db.query(
            func.coalesce(func.sum(Expense.amount), 0)
        ).filter(
            func.date(Expense.expense_date) >= today - timedelta(days=14),
            func.date(Expense.expense_date) < today - timedelta(days=7),
        ).scalar()

        if last_week_expenses > 0 and this_week_expenses > last_week_expenses * Decimal("1.5"):
            increase_pct = ((this_week_expenses - last_week_expenses) / last_week_expenses) * 100
            insights.append({
                "type": "expense_spike",
                "severity": "warning",
                "title": f"Expenses up {increase_pct:.0f}% this week",
                "message": f"This week: ${this_week_expenses:,.0f} vs last week: ${last_week_expenses:,.0f}. Review expense categories.",
                "metric": {"this_week": str(this_week_expenses), "last_week": str(last_week_expenses)},
            })

        return insights

    def opportunity_analysis(self) -> list[dict]:
        """Identify growth opportunities."""
        insights = []

        # Top growing product
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

        prev_sales = {}
        prev_results = self.db.query(
            SalesInvoiceItem.product_id,
            func.sum(SalesInvoiceItem.sold_quantity).label("qty"),
        ).join(SalesInvoice, SalesInvoice.invoice_id == SalesInvoiceItem.invoice_id
        ).filter(
            func.date(SalesInvoice.invoice_date) >= previous,
            func.date(SalesInvoice.invoice_date) < recent,
        ).group_by(SalesInvoiceItem.product_id).all()
        for p in prev_results:
            prev_sales[p.product_id] = float(p.qty)

        trending = []
        for r in recent_sales:
            prev = prev_sales.get(r.product_id, 0)
            if prev > 0:
                growth = ((float(r.qty) - prev) / prev) * 100
                if growth > 30:
                    trending.append((r.product_name, growth))

        if trending:
            trending.sort(key=lambda x: x[1], reverse=True)
            top = trending[0]
            insights.append({
                "type": "trending_product",
                "severity": "info",
                "title": f"{top[0]} trending up {top[1]:.0f}%",
                "message": f"Sales accelerating. Consider increasing stock and promoting this product.",
                "metric": {"product": top[0], "growth": round(top[1], 1)},
            })

        return insights

    def why_profit_dropped(self) -> dict:
        """Detailed explanation of why profit dropped."""
        today = date.today()
        this_week = self._period_summary(today - timedelta(days=7), today)
        last_week = self._period_summary(today - timedelta(days=14), today - timedelta(days=8))

        reasons = []
        if this_week["revenue"] < last_week["revenue"]:
            drop = last_week["revenue"] - this_week["revenue"]
            reasons.append(f"Revenue dropped by ${drop:,.0f} ({((drop/last_week['revenue'])*100):.0f}%)")

        if this_week["cogs_pct"] > last_week["cogs_pct"] + 3:
            reasons.append(f"COGS ratio increased from {last_week['cogs_pct']:.1f}% to {this_week['cogs_pct']:.1f}% (higher purchase costs)")

        if this_week["expenses"] > last_week["expenses"] * Decimal("1.2"):
            increase = this_week["expenses"] - last_week["expenses"]
            reasons.append(f"Expenses increased by ${increase:,.0f}")

        if this_week["sales_count"] < last_week["sales_count"]:
            reasons.append(f"Fewer invoices: {this_week['sales_count']} vs {last_week['sales_count']} last week")

        return {
            "question": "Why did profit drop?",
            "this_week": this_week,
            "last_week": last_week,
            "reasons": reasons if reasons else ["No significant change detected"],
            "recommendation": self._get_recommendation(reasons),
        }

    def top_risks(self, limit: int = 3) -> list[dict]:
        """Get top N risks sorted by severity."""
        all_risks = self.risk_analysis()
        return all_risks[:limit]

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
        gross_margin = ((revenue - cogs) / revenue * 100) if revenue > 0 else 0
        cogs_pct = (cogs / revenue * 100) if revenue > 0 else 0

        return {
            "revenue": result.revenue,
            "cogs": result.cogs,
            "expenses": result.expenses,
            "net_profit": result.net_profit,
            "sales_count": result.sales_count,
            "gross_margin": gross_margin,
            "cogs_pct": cogs_pct,
        }

    def _explain_profit_drop(self, current: dict, previous: dict) -> str:
        parts = []
        if current["revenue"] < previous["revenue"]:
            parts.append(f"Revenue down ${previous['revenue'] - current['revenue']:,.0f}")
        if current["expenses"] > previous["expenses"]:
            parts.append(f"Expenses up ${current['expenses'] - previous['expenses']:,.0f}")
        if current["cogs_pct"] > previous["cogs_pct"] + 2:
            parts.append(f"COGS ratio rose to {current['cogs_pct']:.0f}%")
        if not parts:
            parts.append("Multiple small factors combined")
        return ". ".join(parts) + "."

    def _get_recommendation(self, reasons: list) -> str:
        if any("Revenue" in r for r in reasons):
            return "Focus on sales: promotions, customer follow-ups, or expanding product range."
        if any("COGS" in r for r in reasons):
            return "Negotiate with suppliers or review pricing strategy."
        if any("Expenses" in r for r in reasons):
            return "Review expense categories and cut non-essential spending."
        return "Monitor daily and take action if trend continues."
