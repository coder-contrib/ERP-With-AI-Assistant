from sqlalchemy.orm import Session
from sqlalchemy import func
from decimal import Decimal
from datetime import date
from app.models.accounting import DailyFinancialSummary
from app.models.payments import CashTransaction
from app.models.customers import Customer
from app.models.suppliers import Supplier
from app.models.expenses import Expense


class FinanceTools:
    """Tools for the Accounting AI Agent.
    All data access goes through SQLAlchemy models.
    """

    def __init__(self, db: Session):
        self.db = db

    def get_profit_and_loss(self, start_date: str, end_date: str) -> dict:
        results = self.db.query(
            func.sum(DailyFinancialSummary.revenue).label("revenue"),
            func.sum(DailyFinancialSummary.cogs).label("cogs"),
            func.sum(DailyFinancialSummary.gross_profit).label("gross_profit"),
            func.sum(DailyFinancialSummary.expenses).label("expenses"),
            func.sum(DailyFinancialSummary.net_profit).label("net_profit"),
            func.sum(DailyFinancialSummary.sales_count).label("sales_count"),
        ).filter(
            DailyFinancialSummary.summary_date >= start_date,
            DailyFinancialSummary.summary_date <= end_date,
        ).first()

        return {
            "period": {"start": start_date, "end": end_date},
            "revenue": str(results.revenue or 0),
            "cogs": str(results.cogs or 0),
            "gross_profit": str(results.gross_profit or 0),
            "expenses": str(results.expenses or 0),
            "net_profit": str(results.net_profit or 0),
            "sales_count": results.sales_count or 0,
            "gross_margin": str(
                round((results.gross_profit / results.revenue * 100), 2)
                if results.revenue and results.revenue > 0 else 0
            ),
        }

    def get_cash_balance(self) -> dict:
        cash_in = self.db.query(
            func.coalesce(func.sum(CashTransaction.amount), 0)
        ).filter(CashTransaction.transaction_type == "cash_in").scalar()

        cash_out = self.db.query(
            func.coalesce(func.sum(CashTransaction.amount), 0)
        ).filter(CashTransaction.transaction_type == "cash_out").scalar()

        return {
            "total_cash_in": str(cash_in),
            "total_cash_out": str(cash_out),
            "current_balance": str(cash_in - cash_out),
        }

    def get_receivables_summary(self) -> dict:
        results = self.db.query(
            func.count(Customer.customer_id).label("customer_count"),
            func.sum(Customer.current_balance).label("total_receivable"),
        ).filter(Customer.current_balance > 0).first()

        top_debtors = self.db.query(
            Customer.customer_id,
            Customer.customer_name,
            Customer.current_balance,
        ).filter(Customer.current_balance > 0
        ).order_by(Customer.current_balance.desc()).limit(5).all()

        return {
            "customers_with_balance": results.customer_count or 0,
            "total_receivable": str(results.total_receivable or 0),
            "top_debtors": [
                {"name": c.customer_name, "balance": str(c.current_balance)}
                for c in top_debtors
            ],
        }

    def get_payables_summary(self) -> dict:
        results = self.db.query(
            func.count(Supplier.supplier_id).label("supplier_count"),
            func.sum(Supplier.current_balance).label("total_payable"),
        ).filter(Supplier.current_balance > 0).first()

        top_creditors = self.db.query(
            Supplier.supplier_id,
            Supplier.supplier_name,
            Supplier.current_balance,
        ).filter(Supplier.current_balance > 0
        ).order_by(Supplier.current_balance.desc()).limit(5).all()

        return {
            "suppliers_with_balance": results.supplier_count or 0,
            "total_payable": str(results.total_payable or 0),
            "top_creditors": [
                {"name": s.supplier_name, "balance": str(s.current_balance)}
                for s in top_creditors
            ],
        }

    def get_expense_breakdown(self, start_date: str, end_date: str) -> dict:
        results = self.db.query(
            Expense.expense_category,
            func.count(Expense.expense_id).label("count"),
            func.sum(Expense.amount).label("total"),
        ).filter(
            func.date(Expense.expense_date) >= start_date,
            func.date(Expense.expense_date) <= end_date,
        ).group_by(Expense.expense_category
        ).order_by(func.sum(Expense.amount).desc()).all()

        return {
            "period": {"start": start_date, "end": end_date},
            "categories": [
                {"category": r.expense_category, "count": r.count, "total": str(r.total)}
                for r in results
            ],
            "grand_total": str(sum(r.total for r in results)),
        }

    def get_daily_revenue(self, start_date: str, end_date: str) -> dict:
        results = self.db.query(
            DailyFinancialSummary.summary_date,
            DailyFinancialSummary.revenue,
            DailyFinancialSummary.net_profit,
            DailyFinancialSummary.sales_count,
        ).filter(
            DailyFinancialSummary.summary_date >= start_date,
            DailyFinancialSummary.summary_date <= end_date,
        ).order_by(DailyFinancialSummary.summary_date).all()

        return {
            "period": {"start": start_date, "end": end_date},
            "days": [
                {
                    "date": str(r.summary_date),
                    "revenue": str(r.revenue),
                    "net_profit": str(r.net_profit),
                    "sales_count": r.sales_count,
                }
                for r in results
            ],
        }
