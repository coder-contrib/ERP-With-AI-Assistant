from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from app.core.deps import require_permission
from app.core.redis import get_redis
from app.services.cache_service import CacheService
from app.models.sales import SalesInvoice
from app.models.purchases import PurchaseInvoice
from app.models.customers import Customer
from app.models.suppliers import Supplier
from app.models.inventory import InventoryCache
from app.models.expenses import Expense
from app.models.users import User
from datetime import date

router = APIRouter()


@router.get("/")
def get_dashboard(current_user: User = Depends(require_permission("reports:read")), db: Session = Depends(get_db)):
    cache = CacheService(get_redis())

    cached = cache.get_dashboard()
    if cached:
        return cached

    today = date.today()

    today_sales = db.query(func.coalesce(func.sum(SalesInvoice.total_amount), 0)).filter(
        func.date(SalesInvoice.invoice_date) == today
    ).scalar()

    today_purchases = db.query(func.coalesce(func.sum(PurchaseInvoice.total_amount), 0)).filter(
        func.date(PurchaseInvoice.purchase_date) == today
    ).scalar()

    today_expenses = db.query(func.coalesce(func.sum(Expense.amount), 0)).filter(
        func.date(Expense.expense_date) == today
    ).scalar()

    total_customers = db.query(func.count(Customer.customer_id)).scalar()
    total_suppliers = db.query(func.count(Supplier.supplier_id)).scalar()

    total_receivables = db.query(func.coalesce(func.sum(Customer.current_balance), 0)).filter(
        Customer.current_balance > 0
    ).scalar()

    total_payables = db.query(func.coalesce(func.sum(Supplier.current_balance), 0)).filter(
        Supplier.current_balance > 0
    ).scalar()

    low_stock_count = db.query(func.count(InventoryCache.inventory_id)).filter(
        InventoryCache.cached_quantity <= 10
    ).scalar()

    stats = {
        "today_sales": str(today_sales),
        "today_purchases": str(today_purchases),
        "today_expenses": str(today_expenses),
        "total_customers": total_customers,
        "total_suppliers": total_suppliers,
        "total_receivables": str(total_receivables),
        "total_payables": str(total_payables),
        "low_stock_count": low_stock_count,
    }

    cache.set_dashboard(stats)
    return stats
