from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from datetime import date, timedelta
from app.database import get_db
from app.core.deps import require_permission
from app.models.users import User
from app.services.report_service import ReportService

router = APIRouter()


# ─── EXISTING ENDPOINTS ─────────────────────────────────────────────

@router.get("/daily-sales")
def daily_sales_report(
    start_date: date = Query(default=None),
    end_date: date = Query(default=None),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    if not end_date:
        end_date = date.today()
    service = ReportService(db)
    return {"report": "daily_sales", "data": service.daily_sales(start_date, end_date)}


@router.get("/monthly-profit")
def monthly_profit_report(
    year: int = Query(default=None),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    if not year:
        year = date.today().year
    service = ReportService(db)
    return {"report": "monthly_profit", "year": year, "data": service.monthly_profit(year)}


@router.get("/top-products")
def top_products_report(
    start_date: date = Query(default=None),
    end_date: date = Query(default=None),
    limit: int = Query(default=20),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    if not end_date:
        end_date = date.today()
    service = ReportService(db)
    return {"report": "top_products", "data": service.top_selling_products(start_date, end_date, limit)}


@router.get("/inventory-valuation")
def inventory_valuation_report(
    warehouse_id: int | None = Query(default=None),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    service = ReportService(db)
    return {"report": "inventory_valuation", "data": service.inventory_valuation(warehouse_id)}


@router.get("/customer-balances")
def customer_balances_report(
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    service = ReportService(db)
    data = service.customer_balances()
    total = sum(float(c["current_balance"]) for c in data)
    return {"report": "customer_balances", "total_receivable": str(total), "count": len(data), "data": data}


@router.get("/supplier-balances")
def supplier_balances_report(
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    service = ReportService(db)
    data = service.supplier_balances()
    total = sum(float(s["current_balance"]) for s in data)
    return {"report": "supplier_balances", "total_payable": str(total), "count": len(data), "data": data}


@router.get("/cash-flow")
def cash_flow_report(
    start_date: date = Query(default=None),
    end_date: date = Query(default=None),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    if not end_date:
        end_date = date.today()
    service = ReportService(db)
    return {"report": "cash_flow", "data": service.cash_flow(start_date, end_date)}


@router.get("/waste")
def waste_report(
    start_date: date = Query(default=None),
    end_date: date = Query(default=None),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    if not end_date:
        end_date = date.today()
    service = ReportService(db)
    return {"report": "waste", "data": service.waste_report(start_date, end_date)}


@router.get("/warehouse-stock/{warehouse_id}")
def warehouse_stock_report(
    warehouse_id: int,
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    service = ReportService(db)
    return {"report": "warehouse_stock", "data": service.warehouse_stock(warehouse_id)}


# ─── NEW: SALES REPORTS ─────────────────────────────────────────────

@router.get("/sales-by-period")
def sales_by_period_report(
    period: str = Query(default="day", regex="^(day|week|month)$"),
    start_date: date = Query(default=None),
    end_date: date = Query(default=None),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    if not end_date:
        end_date = date.today()
    service = ReportService(db)
    return {"report": "sales_by_period", "data": service.sales_by_period(period, start_date, end_date)}


@router.get("/sales-invoices")
def sales_invoices_report(
    start_date: date = Query(default=None),
    end_date: date = Query(default=None),
    status: str | None = Query(default=None),
    payment_method: str | None = Query(default=None),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    if not end_date:
        end_date = date.today()
    service = ReportService(db)
    return {"report": "sales_invoices", "data": service.sales_invoices(start_date, end_date, status, payment_method)}


@router.get("/product-performance")
def product_performance_report(
    start_date: date = Query(default=None),
    end_date: date = Query(default=None),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    if not end_date:
        end_date = date.today()
    service = ReportService(db)
    return {"report": "product_performance", "data": service.product_performance(start_date, end_date)}


# ─── NEW: INVENTORY REPORTS ─────────────────────────────────────────

@router.get("/low-stock")
def low_stock_report(
    threshold: int = Query(default=10),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    service = ReportService(db)
    return {"report": "low_stock", "data": service.low_stock_alert(threshold)}


@router.get("/stock-movement")
def stock_movement_report(
    start_date: date = Query(default=None),
    end_date: date = Query(default=None),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    if not end_date:
        end_date = date.today()
    service = ReportService(db)
    return {"report": "stock_movement", "data": service.stock_movement(start_date, end_date)}


@router.get("/dead-stock")
def dead_stock_report(
    days: int = Query(default=30),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    service = ReportService(db)
    return {"report": "dead_stock", "data": service.dead_stock(days)}


# ─── NEW: FINANCE REPORTS ───────────────────────────────────────────

@router.get("/profit-loss")
def profit_loss_report(
    start_date: date = Query(default=None),
    end_date: date = Query(default=None),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    if not end_date:
        end_date = date.today()
    service = ReportService(db)
    return {"report": "profit_loss", "data": service.profit_loss(start_date, end_date)}


@router.get("/expense-by-category")
def expense_by_category_report(
    start_date: date = Query(default=None),
    end_date: date = Query(default=None),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    if not end_date:
        end_date = date.today()
    service = ReportService(db)
    return {"report": "expense_by_category", "data": service.expense_by_category(start_date, end_date)}


# ─── NEW: CUSTOMER REPORTS ──────────────────────────────────────────

@router.get("/customer-profile/{customer_id}")
def customer_profile_report(
    customer_id: int,
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    service = ReportService(db)
    return {"report": "customer_profile", "data": service.customer_profile(customer_id)}


@router.get("/customer-activity/{customer_id}")
def customer_activity_report(
    customer_id: int,
    limit: int = Query(default=50, le=200),
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    service = ReportService(db)
    return {"report": "customer_activity", "data": service.customer_activity(customer_id, limit)}


@router.get("/customer-segmentation")
def customer_segmentation_report(
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    service = ReportService(db)
    return {"report": "customer_segmentation", "data": service.customer_segmentation()}


# ─── NEW: AI-POWERED REPORTS ────────────────────────────────────────

@router.get("/ai-risk-assessment")
def ai_risk_assessment_report(
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    from app.ai.anomaly_detector import AnomalyDetector
    from app.ai.tools.reporting_tools import ReportingTools

    anomaly = AnomalyDetector(db)
    tools = ReportingTools(db)
    service = ReportService(db)

    anomalies = anomaly.scan_all_anomalies()
    low_stock_pred = tools.low_stock_prediction(days_ahead=7)
    dead_stock_data = service.dead_stock(days=30)
    customer_risks = service.customer_balances()
    over_limit = [c for c in customer_risks if c.get("over_limit")]

    risks = []

    for a in anomalies:
        risks.append({
            "type": a["type"].replace("_", " ").title(),
            "severity": "HIGH" if a["severity"] == "critical" else "MEDIUM",
            "title": a["title"],
            "detail": a["message"],
            "detection_method": a["detection_method"],
        })

    if low_stock_pred["at_risk_count"] > 0:
        urgent = [p for p in low_stock_pred["products"] if p["days_left"] <= 3]
        if urgent:
            risks.append({
                "type": "Stock Shortage Predicted",
                "severity": "HIGH",
                "title": f"{len(urgent)} products will run out within 3 days",
                "detail": ", ".join([p["product_name"] for p in urgent[:5]]),
                "detection_method": "ai_prediction",
            })
        else:
            risks.append({
                "type": "Low Stock Forecast",
                "severity": "MEDIUM",
                "title": f"{low_stock_pred['at_risk_count']} products at risk within 7 days",
                "detail": ", ".join([p["product_name"] for p in low_stock_pred["products"][:5]]),
                "detection_method": "ai_prediction",
            })

    if dead_stock_data["dead_stock_count"] > 0:
        capital = float(dead_stock_data["total_capital_locked"])
        risks.append({
            "type": "Dead Stock Capital",
            "severity": "HIGH" if capital > 50000 else "MEDIUM",
            "title": f"{dead_stock_data['dead_stock_count']} products with no movement in 30 days",
            "detail": f"{capital:,.0f} IQD capital locked in non-moving inventory",
            "detection_method": "inventory_analysis",
        })

    if over_limit:
        total_over = sum(float(c["current_balance"]) for c in over_limit)
        risks.append({
            "type": "Credit Exposure",
            "severity": "HIGH",
            "title": f"{len(over_limit)} customers over credit limit",
            "detail": f"Total overdue exposure: {total_over:,.0f} IQD",
            "detection_method": "credit_analysis",
        })

    severity_order = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
    risks.sort(key=lambda r: severity_order.get(r["severity"], 3))

    return {
        "report": "ai_risk_assessment",
        "data": {
            "generated_at": str(date.today()),
            "total_risks": len(risks),
            "high_severity_count": len([r for r in risks if r["severity"] == "HIGH"]),
            "medium_severity_count": len([r for r in risks if r["severity"] == "MEDIUM"]),
            "risks": risks,
            "anomalies_detected": len(anomalies),
            "stock_at_risk": low_stock_pred["at_risk_count"],
        },
    }


@router.get("/ai-daily-summary")
def ai_daily_summary_report(
    current_user: User = Depends(require_permission("reports:read")),
    db: Session = Depends(get_db),
):
    from app.ai.anomaly_detector import AnomalyDetector
    from app.ai.tools.reporting_tools import ReportingTools

    anomaly = AnomalyDetector(db)
    tools = ReportingTools(db)
    service = ReportService(db)

    today = date.today()
    start_30d = today - timedelta(days=30)

    profit_data = tools.profit_analysis(str(start_30d), str(today))
    revenue_anomaly = anomaly.detect_revenue_anomaly()
    expense_anomaly = anomaly.detect_expense_anomaly()
    profit_anomaly = anomaly.detect_profit_anomaly()
    trending = tools.best_selling_prediction(days_back=14)
    stock_pred = tools.low_stock_prediction(days_ahead=7)
    daily_sales = service.daily_sales(today - timedelta(days=2), today)

    insights = []

    if revenue_anomaly["current"] > 0:
        if revenue_anomaly["is_anomaly"]:
            direction = "above" if revenue_anomaly["direction"] == "high" else "below"
            insights.append({
                "category": "Revenue",
                "icon": "trending_up" if direction == "above" else "trending_down",
                "text": f"Today's revenue ({revenue_anomaly['current']:,.0f} IQD) is significantly {direction} the 30-day average ({revenue_anomaly['mean_30d']:,.0f} IQD). Z-score: {revenue_anomaly['z_score']:.1f}",
                "sentiment": "positive" if direction == "above" else "negative",
            })
        else:
            insights.append({
                "category": "Revenue",
                "icon": "check_circle",
                "text": f"Revenue is normal today ({revenue_anomaly['current']:,.0f} IQD vs avg {revenue_anomaly['mean_30d']:,.0f} IQD).",
                "sentiment": "neutral",
            })

    if profit_data and "profit_trend" in profit_data:
        if profit_data["profit_trend"] == "decreasing":
            insights.append({
                "category": "Profit Trend",
                "icon": "warning",
                "text": f"Profit is trending downward. Net margin: {profit_data['net_margin_percent']}%. Issues: {'; '.join(profit_data.get('issues', []))}",
                "sentiment": "negative",
            })
        elif profit_data["profit_trend"] == "increasing":
            insights.append({
                "category": "Profit Trend",
                "icon": "trending_up",
                "text": f"Profit is trending upward. Net margin: {profit_data['net_margin_percent']}%. Revenue: {profit_data['total_revenue']} IQD over 30 days.",
                "sentiment": "positive",
            })
        else:
            insights.append({
                "category": "Profit Trend",
                "icon": "check_circle",
                "text": f"Profit is stable. Net margin: {profit_data['net_margin_percent']}%.",
                "sentiment": "neutral",
            })

    if expense_anomaly["is_anomaly"] and expense_anomaly["direction"] == "high":
        insights.append({
            "category": "Expenses",
            "icon": "error",
            "text": f"Expense spike detected: {expense_anomaly['current']:,.0f} IQD vs average {expense_anomaly['mean_30d']:,.0f} IQD. Investigate large transactions.",
            "sentiment": "negative",
        })

    trending_up = trending.get("trending_up", [])[:3]
    if trending_up:
        names = ", ".join([p["product_name"] for p in trending_up])
        insights.append({
            "category": "Product Trends",
            "icon": "star",
            "text": f"Top trending products (14-day acceleration): {names}. Growth: {trending_up[0]['growth_percent']}%.",
            "sentiment": "positive",
        })

    if stock_pred["at_risk_count"] > 0:
        critical = [p for p in stock_pred["products"] if p["days_left"] <= 3]
        if critical:
            names = ", ".join([p["product_name"] for p in critical[:3]])
            insights.append({
                "category": "Stock Alert",
                "icon": "inventory",
                "text": f"URGENT: {len(critical)} products will run out within 3 days: {names}. Reorder immediately.",
                "sentiment": "negative",
            })
        else:
            insights.append({
                "category": "Stock Alert",
                "icon": "info",
                "text": f"{stock_pred['at_risk_count']} products may run out within 7 days based on current sales velocity.",
                "sentiment": "warning",
            })

    if len(daily_sales) >= 2:
        today_sales = float(daily_sales[-1].get("total_sales", 0))
        yesterday_sales = float(daily_sales[-2].get("total_sales", 0))
        if yesterday_sales > 0:
            change_pct = (today_sales - yesterday_sales) / yesterday_sales * 100
            insights.append({
                "category": "Daily Comparison",
                "icon": "compare_arrows",
                "text": f"Sales today: {today_sales:,.0f} IQD ({change_pct:+.1f}% vs yesterday). Invoices: {daily_sales[-1].get('invoice_count', 0)}.",
                "sentiment": "positive" if change_pct > 0 else "negative",
            })

    return {
        "report": "ai_daily_summary",
        "data": {
            "generated_at": str(today),
            "insights": insights,
            "metrics": {
                "revenue_today": revenue_anomaly.get("current", 0),
                "revenue_avg_30d": revenue_anomaly.get("mean_30d", 0),
                "profit_trend": profit_data.get("profit_trend", "unknown") if profit_data else "unknown",
                "net_margin": profit_data.get("net_margin_percent", 0) if profit_data else 0,
                "stock_at_risk": stock_pred["at_risk_count"],
                "anomalies_detected": sum([
                    1 if revenue_anomaly.get("is_anomaly") else 0,
                    1 if expense_anomaly.get("is_anomaly") else 0,
                    1 if profit_anomaly.get("is_anomaly") else 0,
                ]),
            },
        },
    }
