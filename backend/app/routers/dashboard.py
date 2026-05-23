from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func, case
from datetime import date
from app.database import get_db
from app.core.deps import get_current_user
from app.core.redis import get_redis
from app.services.cache_service import CacheService
from app.models.sales import SalesInvoice
from app.models.purchases import PurchaseInvoice
from app.models.customers import Customer
from app.models.suppliers import Supplier
from app.models.inventory import InventoryCache
from app.models.expenses import Expense
from app.models.payments import CashTransaction
from app.models.accounting import DailyFinancialSummary
from app.models.users import User

router = APIRouter()


@router.get("/summary")
def get_dashboard_summary(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    cache = CacheService(get_redis())
    cached = cache.get_dashboard()
    if cached:
        return cached

    today = date.today()
    first_of_month = today.replace(day=1)

    # Today's sales
    today_sales = db.query(
        func.coalesce(func.sum(SalesInvoice.total_amount), 0)
    ).filter(func.date(SalesInvoice.invoice_date) == today).scalar()

    # Monthly profit from precomputed summary
    monthly_profit = db.query(
        func.coalesce(func.sum(DailyFinancialSummary.net_profit), 0)
    ).filter(
        DailyFinancialSummary.summary_date >= first_of_month,
        DailyFinancialSummary.summary_date <= today,
    ).scalar()

    # Low stock products (quantity <= 10)
    low_stock_products = db.query(
        func.count(InventoryCache.inventory_id)
    ).filter(InventoryCache.cached_quantity <= 10, InventoryCache.cached_quantity > 0).scalar()

    # Pending payments (unpaid + partial invoices)
    pending_payments = db.query(
        func.count(SalesInvoice.invoice_id)
    ).filter(SalesInvoice.payment_status.in_(["unpaid", "partial"])).scalar()

    # Cash balance
    cash_in = db.query(
        func.coalesce(func.sum(CashTransaction.amount), 0)
    ).filter(CashTransaction.transaction_type == "cash_in").scalar()
    cash_out = db.query(
        func.coalesce(func.sum(CashTransaction.amount), 0)
    ).filter(CashTransaction.transaction_type == "cash_out").scalar()
    cash_balance = cash_in - cash_out

    # Today's purchases
    today_purchases = db.query(
        func.coalesce(func.sum(PurchaseInvoice.total_amount), 0)
    ).filter(func.date(PurchaseInvoice.purchase_date) == today).scalar()

    # Today's expenses
    today_expenses = db.query(
        func.coalesce(func.sum(Expense.amount), 0)
    ).filter(func.date(Expense.expense_date) == today).scalar()

    # Total receivables
    total_receivables = db.query(
        func.coalesce(func.sum(Customer.current_balance), 0)
    ).filter(Customer.current_balance > 0).scalar()

    # Total payables
    total_payables = db.query(
        func.coalesce(func.sum(Supplier.current_balance), 0)
    ).filter(Supplier.current_balance > 0).scalar()

    # Monthly revenue
    monthly_revenue = db.query(
        func.coalesce(func.sum(DailyFinancialSummary.revenue), 0)
    ).filter(
        DailyFinancialSummary.summary_date >= first_of_month,
        DailyFinancialSummary.summary_date <= today,
    ).scalar()

    summary = {
        "today_sales": str(today_sales),
        "today_purchases": str(today_purchases),
        "today_expenses": str(today_expenses),
        "monthly_revenue": str(monthly_revenue),
        "monthly_profit": str(monthly_profit),
        "low_stock_products": low_stock_products,
        "pending_payments": pending_payments,
        "cash_balance": str(cash_balance),
        "total_receivables": str(total_receivables),
        "total_payables": str(total_payables),
    }

    cache.set_dashboard(summary)
    return summary
