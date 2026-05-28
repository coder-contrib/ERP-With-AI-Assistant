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
