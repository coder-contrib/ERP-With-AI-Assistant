from sqlalchemy.orm import Session
from sqlalchemy import func
from decimal import Decimal
from datetime import date, timedelta
import math
from app.models.accounting import DailyFinancialSummary
from app.models.sales import SalesInvoice
from app.models.expenses import Expense
from app.models.inventory import InventoryCache


class AnomalyDetector:
    """Adaptive intelligence using statistical anomaly detection.
    Replaces static thresholds with dynamic, data-driven baselines.

    Methods:
    - Z-score: detects values significantly different from historical mean
    - Rolling average: compares recent values to moving baseline
    - Seasonal baseline: accounts for day-of-week patterns
    """

    def __init__(self, db: Session):
        self.db = db

    # ========================================================
    # Z-SCORE ANOMALY DETECTION
    # ========================================================

    def z_score(self, values: list[float], current: float) -> float:
        """Calculate z-score of current value against historical distribution.
        |z| > 2 = unusual, |z| > 3 = very unusual.
        """
        if len(values) < 3:
            return 0.0
        mean = sum(values) / len(values)
        variance = sum((x - mean) ** 2 for x in values) / len(values)
        std = math.sqrt(variance) if variance > 0 else 0
        if std == 0:
            return 0.0
        return (current - mean) / std

    def detect_revenue_anomaly(self, target_date: date | None = None) -> dict:
        """Detect if today's/target revenue is anomalous vs last 30 days."""
        target = target_date or date.today()
        lookback = 30

        history = self.db.query(DailyFinancialSummary.revenue).filter(
            DailyFinancialSummary.summary_date >= target - timedelta(days=lookback),
            DailyFinancialSummary.summary_date < target,
        ).all()
        values = [float(r.revenue) for r in history]

        current = self.db.query(DailyFinancialSummary.revenue).filter(
            DailyFinancialSummary.summary_date == target
        ).scalar()
        current_val = float(current) if current else 0

        z = self.z_score(values, current_val)
        mean = sum(values) / len(values) if values else 0

        return {
            "metric": "revenue",
            "date": str(target),
            "current": current_val,
            "mean_30d": round(mean, 2),
            "z_score": round(z, 2),
            "is_anomaly": abs(z) > 2,
            "direction": "high" if z > 2 else ("low" if z < -2 else "normal"),
            "severity": "critical" if abs(z) > 3 else ("warning" if abs(z) > 2 else "normal"),
        }

    def detect_expense_anomaly(self, target_date: date | None = None) -> dict:
        """Detect if today's expenses are anomalous."""
        target = target_date or date.today()
        lookback = 30

        history = self.db.query(DailyFinancialSummary.expenses).filter(
            DailyFinancialSummary.summary_date >= target - timedelta(days=lookback),
            DailyFinancialSummary.summary_date < target,
        ).all()
        values = [float(r.expenses) for r in history if r.expenses > 0]

        current = self.db.query(DailyFinancialSummary.expenses).filter(
            DailyFinancialSummary.summary_date == target
        ).scalar()
        current_val = float(current) if current else 0

        z = self.z_score(values, current_val)
        mean = sum(values) / len(values) if values else 0

        return {
            "metric": "expenses",
            "date": str(target),
            "current": current_val,
            "mean_30d": round(mean, 2),
            "z_score": round(z, 2),
            "is_anomaly": abs(z) > 2,
            "direction": "high" if z > 2 else ("low" if z < -2 else "normal"),
            "severity": "critical" if z > 3 else ("warning" if z > 2 else "normal"),
        }

    def detect_profit_anomaly(self, target_date: date | None = None) -> dict:
        """Detect if profit is anomalously low."""
        target = target_date or date.today()
        lookback = 30

        history = self.db.query(DailyFinancialSummary.net_profit).filter(
            DailyFinancialSummary.summary_date >= target - timedelta(days=lookback),
            DailyFinancialSummary.summary_date < target,
        ).all()
        values = [float(r.net_profit) for r in history]

        current = self.db.query(DailyFinancialSummary.net_profit).filter(
            DailyFinancialSummary.summary_date == target
        ).scalar()
        current_val = float(current) if current else 0

        z = self.z_score(values, current_val)
        mean = sum(values) / len(values) if values else 0

        return {
            "metric": "net_profit",
            "date": str(target),
            "current": current_val,
            "mean_30d": round(mean, 2),
            "z_score": round(z, 2),
            "is_anomaly": abs(z) > 2,
            "direction": "high" if z > 2 else ("low" if z < -2 else "normal"),
            "severity": "critical" if z < -3 else ("warning" if z < -2 else "normal"),
        }

    # ========================================================
    # ROLLING AVERAGE BASELINE
    # ========================================================

    def rolling_average(self, values: list[float], window: int = 7) -> list[float]:
        """Calculate rolling average with given window."""
        if len(values) < window:
            return values
        result = []
        for i in range(len(values) - window + 1):
            avg = sum(values[i:i + window]) / window
            result.append(avg)
        return result

    def revenue_vs_rolling_baseline(self, days: int = 7) -> dict:
        """Compare recent revenue to 7-day rolling average baseline."""
        lookback = 60
        today = date.today()

        history = self.db.query(
            DailyFinancialSummary.summary_date,
            DailyFinancialSummary.revenue,
        ).filter(
            DailyFinancialSummary.summary_date >= today - timedelta(days=lookback),
            DailyFinancialSummary.summary_date <= today,
        ).order_by(DailyFinancialSummary.summary_date).all()

        if len(history) < days * 2:
            return {"status": "insufficient_data"}

        values = [float(r.revenue) for r in history]
        rolling = self.rolling_average(values, days)

        recent_avg = sum(values[-days:]) / days if len(values) >= days else 0
        baseline_avg = sum(rolling[:-days]) / len(rolling[:-days]) if len(rolling) > days else recent_avg

        deviation_pct = ((recent_avg - baseline_avg) / baseline_avg * 100) if baseline_avg > 0 else 0

        return {
            "metric": "revenue",
            "window_days": days,
            "recent_avg": round(recent_avg, 2),
            "baseline_avg": round(baseline_avg, 2),
            "deviation_pct": round(deviation_pct, 1),
            "is_anomaly": abs(deviation_pct) > 25,
            "direction": "above" if deviation_pct > 25 else ("below" if deviation_pct < -25 else "normal"),
            "trend": values[-days:],
        }

    # ========================================================
    # SEASONAL BASELINE (Day-of-Week Patterns)
    # ========================================================

    def seasonal_baseline(self, target_date: date | None = None) -> dict:
        """Compare today's performance to same-day-of-week historical average."""
        target = target_date or date.today()
        day_of_week = target.weekday()
        lookback_weeks = 8

        same_day_dates = [target - timedelta(weeks=w) for w in range(1, lookback_weeks + 1)]

        history = self.db.query(
            DailyFinancialSummary.revenue,
            DailyFinancialSummary.net_profit,
            DailyFinancialSummary.sales_count,
        ).filter(
            DailyFinancialSummary.summary_date.in_(same_day_dates)
        ).all()

        if not history:
            return {"status": "insufficient_data"}

        avg_revenue = sum(float(r.revenue) for r in history) / len(history)
        avg_profit = sum(float(r.net_profit) for r in history) / len(history)
        avg_sales_count = sum(r.sales_count for r in history) / len(history)

        current = self.db.query(DailyFinancialSummary).filter(
            DailyFinancialSummary.summary_date == target
        ).first()

        if not current:
            return {"status": "no_data_today"}

        current_revenue = float(current.revenue)
        current_profit = float(current.net_profit)
        current_count = current.sales_count

        rev_deviation = ((current_revenue - avg_revenue) / avg_revenue * 100) if avg_revenue > 0 else 0
        profit_deviation = ((current_profit - avg_profit) / abs(avg_profit) * 100) if avg_profit != 0 else 0

        day_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

        return {
            "date": str(target),
            "day_of_week": day_names[day_of_week],
            "baseline_weeks": lookback_weeks,
            "revenue": {
                "current": current_revenue,
                "seasonal_avg": round(avg_revenue, 2),
                "deviation_pct": round(rev_deviation, 1),
                "is_anomaly": abs(rev_deviation) > 30,
            },
            "profit": {
                "current": current_profit,
                "seasonal_avg": round(avg_profit, 2),
                "deviation_pct": round(profit_deviation, 1),
                "is_anomaly": abs(profit_deviation) > 30,
            },
            "sales_count": {
                "current": current_count,
                "seasonal_avg": round(avg_sales_count, 1),
            },
        }

    # ========================================================
    # COMBINED ANOMALY SCAN
    # ========================================================

    def scan_all_anomalies(self) -> list[dict]:
        """Run all anomaly detection methods and return findings."""
        anomalies = []

        revenue = self.detect_revenue_anomaly()
        if revenue["is_anomaly"]:
            anomalies.append({
                "type": "revenue_anomaly",
                "severity": revenue["severity"],
                "title": f"Revenue {'spike' if revenue['direction'] == 'high' else 'drop'} detected (z={revenue['z_score']})",
                "message": f"Today: ${revenue['current']:,.0f} vs 30-day avg: ${revenue['mean_30d']:,.0f}. This is {abs(revenue['z_score']):.1f} standard deviations from normal.",
                "metric": revenue,
                "detection_method": "z_score",
            })

        expenses = self.detect_expense_anomaly()
        if expenses["is_anomaly"] and expenses["direction"] == "high":
            anomalies.append({
                "type": "expense_anomaly",
                "severity": expenses["severity"],
                "title": f"Unusual expense spike (z={expenses['z_score']})",
                "message": f"Today: ${expenses['current']:,.0f} vs 30-day avg: ${expenses['mean_30d']:,.0f}. Investigate large transactions.",
                "metric": expenses,
                "detection_method": "z_score",
            })

        profit = self.detect_profit_anomaly()
        if profit["is_anomaly"] and profit["direction"] == "low":
            anomalies.append({
                "type": "profit_anomaly",
                "severity": profit["severity"],
                "title": f"Profit significantly below normal (z={profit['z_score']})",
                "message": f"Today: ${profit['current']:,.0f} vs 30-day avg: ${profit['mean_30d']:,.0f}. Check margins and costs.",
                "metric": profit,
                "detection_method": "z_score",
            })

        rolling = self.revenue_vs_rolling_baseline()
        if rolling.get("is_anomaly") and rolling.get("direction") == "below":
            anomalies.append({
                "type": "revenue_trend_anomaly",
                "severity": "warning",
                "title": f"Revenue {abs(rolling['deviation_pct']):.0f}% below rolling baseline",
                "message": f"7-day avg: ${rolling['recent_avg']:,.0f} vs baseline: ${rolling['baseline_avg']:,.0f}. Sustained downtrend.",
                "metric": rolling,
                "detection_method": "rolling_average",
            })

        seasonal = self.seasonal_baseline()
        if seasonal.get("revenue", {}).get("is_anomaly") and seasonal["revenue"]["deviation_pct"] < -30:
            anomalies.append({
                "type": "seasonal_anomaly",
                "severity": "warning",
                "title": f"Revenue {abs(seasonal['revenue']['deviation_pct']):.0f}% below {seasonal['day_of_week']} average",
                "message": f"Today: ${seasonal['revenue']['current']:,.0f} vs typical {seasonal['day_of_week']}: ${seasonal['revenue']['seasonal_avg']:,.0f}",
                "metric": seasonal,
                "detection_method": "seasonal_baseline",
            })

        anomalies.sort(key=lambda x: {"critical": 0, "warning": 1, "info": 2}.get(x["severity"], 3))
        return anomalies
