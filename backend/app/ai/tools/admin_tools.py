"""Admin & system tools — fills the remaining gaps between backend services and AI tools."""
from sqlalchemy.orm import Session
from sqlalchemy import func, text
from decimal import Decimal
from datetime import date, timedelta
import logging

logger = logging.getLogger(__name__)


class AdminTools:
    def __init__(self, db: Session):
        self.db = db

    # ═══ Categories ═══

    def list_categories(self) -> dict:
        from app.models.categories import Category
        cats = self.db.query(Category).order_by(Category.category_name).all()
        return {
            "categories": [
                {"category_id": c.category_id, "category_name": c.category_name, "description": c.description}
                for c in cats
            ],
            "total": len(cats),
        }

    def create_category(self, name: str, description: str | None = None) -> dict:
        from app.models.categories import Category
        from app.database import transaction
        with transaction(self.db):
            cat = Category(category_name=name, description=description or "")
            self.db.add(cat)
            self.db.flush()
            cat_id = cat.category_id
        self.db.refresh(cat)
        return {"category_id": cat_id, "category_name": name, "status": "created"}

    def update_category(self, category_id: int, name: str | None = None, description: str | None = None) -> dict:
        from app.models.categories import Category
        from app.database import transaction
        cat = self.db.query(Category).filter(Category.category_id == category_id).first()
        if not cat:
            return {"error": f"Category #{category_id} not found"}
        with transaction(self.db):
            if name is not None:
                cat.category_name = name
            if description is not None:
                cat.description = description
        self.db.refresh(cat)
        return {"category_id": category_id, "category_name": cat.category_name, "status": "updated"}

    def delete_category(self, category_id: int) -> dict:
        from app.models.categories import Category
        from app.database import transaction
        cat = self.db.query(Category).filter(Category.category_id == category_id).first()
        if not cat:
            return {"error": f"Category #{category_id} not found"}
        with transaction(self.db):
            self.db.delete(cat)
        return {"category_id": category_id, "status": "deleted"}

    # ═══ Reports: Monthly Profit ═══

    def get_monthly_profit(self, year: int | None = None) -> dict:
        from app.services.report_service import ReportService
        svc = ReportService(self.db)
        target_year = year or date.today().year
        data = svc.monthly_profit(target_year)
        return {"year": target_year, "months": data}

    # ═══ Reports: Cash Flow ═══

    def get_cash_flow(self, start_date: str, end_date: str) -> dict:
        from app.services.report_service import ReportService
        svc = ReportService(self.db)
        start = date.fromisoformat(start_date)
        end = date.fromisoformat(end_date)
        return svc.cash_flow(start, end)

    # ═══ Reports: Waste ═══

    def get_waste_report(self, start_date: str | None = None, end_date: str | None = None) -> dict:
        from app.services.report_service import ReportService
        svc = ReportService(self.db)
        end = date.fromisoformat(end_date) if end_date else date.today()
        start = date.fromisoformat(start_date) if start_date else end - timedelta(days=30)
        return svc.waste_report(start, end)

    # ═══ Notifications ═══

    def get_notifications(self, unread_only: bool = False, limit: int = 50) -> dict:
        from app.services.notification_service import NotificationService
        svc = NotificationService(self.db)
        if unread_only:
            notifs = svc.get_unread()
        else:
            notifs = svc.get_all(limit=limit)
        return {
            "notifications": [
                {
                    "notification_id": n.notification_id,
                    "type": n.notification_type,
                    "severity": n.severity,
                    "title": n.title,
                    "message": n.message,
                    "is_read": n.is_read,
                    "created_date": str(n.created_date),
                    "entity_type": n.entity_type,
                    "entity_id": n.entity_id,
                }
                for n in notifs
            ],
            "total": len(notifs),
        }

    def mark_notification_read(self, notification_id: int) -> dict:
        from app.services.notification_service import NotificationService
        svc = NotificationService(self.db)
        svc.mark_read(notification_id)
        return {"notification_id": notification_id, "status": "marked_read"}

    def mark_all_notifications_read(self) -> dict:
        from app.services.notification_service import NotificationService
        svc = NotificationService(self.db)
        svc.mark_all_read()
        return {"status": "all_marked_read"}

    # ═══ Alerts (trigger checks) ═══

    def check_low_stock_alerts(self, threshold: float = 10.0) -> dict:
        from app.services.notification_service import NotificationService
        svc = NotificationService(self.db)
        count = svc.check_low_stock(threshold)
        return {"new_alerts_created": count, "threshold": threshold, "status": "checked"}

    def check_credit_limit_alerts(self) -> dict:
        from app.services.notification_service import NotificationService
        svc = NotificationService(self.db)
        count = svc.check_credit_limit_exceeded()
        return {"new_alerts_created": count, "status": "checked"}

    def check_overdue_supplier_alerts(self) -> dict:
        from app.services.notification_service import NotificationService
        svc = NotificationService(self.db)
        count = svc.check_overdue_supplier_payments()
        return {"new_alerts_created": count, "status": "checked"}

    # ═══ Anomaly Detection ═══

    def scan_anomalies(self) -> dict:
        from app.ai.anomaly_detector import AnomalyDetector
        detector = AnomalyDetector(self.db)
        anomalies = detector.scan_all_anomalies()
        return {"anomalies": anomalies, "total": len(anomalies)}

    def detect_revenue_anomaly(self, target_date: str | None = None) -> dict:
        from app.ai.anomaly_detector import AnomalyDetector
        detector = AnomalyDetector(self.db)
        d = date.fromisoformat(target_date) if target_date else None
        return detector.detect_revenue_anomaly(d)

    def detect_expense_anomaly(self, target_date: str | None = None) -> dict:
        from app.ai.anomaly_detector import AnomalyDetector
        detector = AnomalyDetector(self.db)
        d = date.fromisoformat(target_date) if target_date else None
        return detector.detect_expense_anomaly(d)

    # ═══ Business Insights ═══

    def get_business_insights(self) -> dict:
        from app.services.insights_service import InsightsService
        svc = InsightsService(self.db)
        insights = svc.get_all_insights()
        return {"insights": insights, "total": len(insights)}

    def why_profit_dropped(self) -> dict:
        from app.services.insights_service import InsightsService
        svc = InsightsService(self.db)
        return svc.why_profit_dropped()

    def get_top_risks(self, limit: int = 5) -> dict:
        from app.services.insights_service import InsightsService
        svc = InsightsService(self.db)
        risks = svc.top_risks(limit)
        return {"risks": risks, "total": len(risks)}

    # ═══ Dashboard Summary ═══

    def get_dashboard_summary(self) -> dict:
        from app.models.sales import SalesInvoice
        from app.models.purchases import PurchaseInvoice
        from app.models.customers import Customer
        from app.models.suppliers import Supplier
        from app.models.inventory import InventoryCache
        from app.models.expenses import Expense
        from app.models.payments import CashTransaction
        from app.models.accounting import DailyFinancialSummary

        today = date.today()
        first_of_month = today.replace(day=1)

        today_sales = self.db.query(
            func.coalesce(func.sum(SalesInvoice.total_amount), 0)
        ).filter(func.date(SalesInvoice.invoice_date) == today).scalar()

        monthly_profit = self.db.query(
            func.coalesce(func.sum(DailyFinancialSummary.net_profit), 0)
        ).filter(
            DailyFinancialSummary.summary_date >= first_of_month,
            DailyFinancialSummary.summary_date <= today,
        ).scalar()

        low_stock_products = self.db.query(
            func.count(InventoryCache.inventory_id)
        ).filter(InventoryCache.cached_quantity <= 10, InventoryCache.cached_quantity > 0).scalar()

        pending_payments = self.db.query(
            func.count(SalesInvoice.invoice_id)
        ).filter(SalesInvoice.payment_status.in_(["unpaid", "partial"])).scalar()

        cash_in = self.db.query(
            func.coalesce(func.sum(CashTransaction.amount), 0)
        ).filter(CashTransaction.transaction_type == "cash_in").scalar()
        cash_out = self.db.query(
            func.coalesce(func.sum(CashTransaction.amount), 0)
        ).filter(CashTransaction.transaction_type == "cash_out").scalar()
        cash_balance = cash_in - cash_out

        today_purchases = self.db.query(
            func.coalesce(func.sum(PurchaseInvoice.total_amount), 0)
        ).filter(func.date(PurchaseInvoice.purchase_date) == today).scalar()

        today_expenses = self.db.query(
            func.coalesce(func.sum(Expense.amount), 0)
        ).filter(func.date(Expense.expense_date) == today).scalar()

        total_receivables = self.db.query(
            func.coalesce(func.sum(Customer.current_balance), 0)
        ).filter(Customer.current_balance > 0).scalar()

        total_payables = self.db.query(
            func.coalesce(func.sum(Supplier.current_balance), 0)
        ).filter(Supplier.current_balance > 0).scalar()

        monthly_revenue = self.db.query(
            func.coalesce(func.sum(DailyFinancialSummary.revenue), 0)
        ).filter(
            DailyFinancialSummary.summary_date >= first_of_month,
            DailyFinancialSummary.summary_date <= today,
        ).scalar()

        return {
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

    # ═══ Tasks (trigger background jobs) ═══

    def refresh_daily_summary(self, target_date: str | None = None) -> dict:
        from app.services.accounting_service import AccountingService
        svc = AccountingService(self.db)
        d = date.fromisoformat(target_date) if target_date else None
        svc.refresh_daily_summary(d)
        return {"status": "refreshed", "date": target_date or str(date.today())}

    def refresh_summary_range(self, start_date: str, end_date: str | None = None) -> dict:
        from app.services.accounting_service import AccountingService
        svc = AccountingService(self.db)
        s = date.fromisoformat(start_date)
        e = date.fromisoformat(end_date) if end_date else None
        svc.refresh_summary_range(s, e)
        return {"status": "refreshed", "start_date": start_date, "end_date": end_date or "today"}

    # ═══ User Management ═══

    def list_users(self) -> dict:
        from app.models.users import User
        users = self.db.query(User).all()
        return {
            "users": [
                {
                    "user_id": u.user_id,
                    "full_name": u.full_name,
                    "username": u.username,
                    "role": u.role,
                    "active_status": u.active_status,
                }
                for u in users
            ],
            "total": len(users),
        }

    def create_user(self, full_name: str, username: str, password: str, role: str) -> dict:
        from app.models.users import User
        from app.core.security import hash_password
        from app.database import transaction
        existing = self.db.query(User).filter(User.username == username).first()
        if existing:
            return {"error": f"Username '{username}' already exists"}
        with transaction(self.db):
            user = User(
                full_name=full_name,
                username=username,
                password=hash_password(password),
                role=role,
            )
            self.db.add(user)
            self.db.flush()
            uid = user.user_id
        return {"user_id": uid, "username": username, "role": role, "status": "created"}

    def deactivate_user(self, user_id: int) -> dict:
        from app.models.users import User
        from app.database import transaction
        user = self.db.query(User).filter(User.user_id == user_id).first()
        if not user:
            return {"error": f"User #{user_id} not found"}
        with transaction(self.db):
            user.active_status = False
        return {"user_id": user_id, "status": "deactivated"}

    def activate_user(self, user_id: int) -> dict:
        from app.models.users import User
        from app.database import transaction
        user = self.db.query(User).filter(User.user_id == user_id).first()
        if not user:
            return {"error": f"User #{user_id} not found"}
        with transaction(self.db):
            user.active_status = True
        return {"user_id": user_id, "status": "activated"}

    def reset_user_password(self, user_id: int) -> dict:
        from app.models.users import User
        from app.core.security import hash_password
        from app.database import transaction
        user = self.db.query(User).filter(User.user_id == user_id).first()
        if not user:
            return {"error": f"User #{user_id} not found"}
        with transaction(self.db):
            user.password = hash_password("123456")
        return {"user_id": user_id, "status": "password_reset", "new_password": "123456"}

    # ═══ Ledger / Journal Entries ═══

    def get_ledger_entries(self, entity_type: str | None = None, entity_id: int | None = None, limit: int = 50) -> dict:
        from app.models.accounting import LedgerEntry
        query = self.db.query(LedgerEntry)
        if entity_type:
            query = query.filter(LedgerEntry.entity_type == entity_type)
        if entity_id:
            query = query.filter(LedgerEntry.entity_id == entity_id)
        entries = query.order_by(LedgerEntry.created_at.desc()).limit(limit).all()
        return {
            "entries": [
                {
                    "entry_id": e.entry_id,
                    "account_id": e.account_id,
                    "debit": str(e.debit),
                    "credit": str(e.credit),
                    "entity_type": e.entity_type,
                    "entity_id": e.entity_id,
                    "description": e.description,
                    "created_at": str(e.created_at),
                }
                for e in entries
            ],
            "total": len(entries),
        }

    def get_account_balance(self, account_id: int) -> dict:
        from app.models.accounting import LedgerEntry
        result = self.db.query(
            func.coalesce(func.sum(LedgerEntry.debit), 0).label("total_debit"),
            func.coalesce(func.sum(LedgerEntry.credit), 0).label("total_credit"),
        ).filter(LedgerEntry.account_id == account_id).first()
        total_debit = result.total_debit
        total_credit = result.total_credit
        return {
            "account_id": account_id,
            "total_debit": str(total_debit),
            "total_credit": str(total_credit),
            "net_balance": str(total_debit - total_credit),
        }

    def get_trial_balance(self) -> dict:
        from app.models.accounting import LedgerEntry
        from app.services.ledger_service import ACCOUNT_CODES
        results = self.db.query(
            LedgerEntry.account_id,
            func.coalesce(func.sum(LedgerEntry.debit), 0).label("total_debit"),
            func.coalesce(func.sum(LedgerEntry.credit), 0).label("total_credit"),
        ).group_by(LedgerEntry.account_id).all()

        code_to_name = {v: k for k, v in ACCOUNT_CODES.items()}
        accounts = []
        for r in results:
            accounts.append({
                "account_id": r.account_id,
                "account_name": code_to_name.get(r.account_id, f"account_{r.account_id}"),
                "total_debit": str(r.total_debit),
                "total_credit": str(r.total_credit),
                "net": str(r.total_debit - r.total_credit),
            })
        total_debits = sum(r.total_debit for r in results)
        total_credits = sum(r.total_credit for r in results)
        return {
            "accounts": accounts,
            "total_debits": str(total_debits),
            "total_credits": str(total_credits),
            "balanced": total_debits == total_credits,
        }
