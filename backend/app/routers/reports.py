from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from datetime import date, timedelta
from app.database import get_db
from app.core.deps import require_permission
from app.models.users import User
from app.services.report_service import ReportService

router = APIRouter()


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
