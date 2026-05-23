from app.celery_app import celery_app
from app.database import SessionLocal
from sqlalchemy import text
from datetime import date, timedelta


@celery_app.task(name="app.tasks.reports.check_overdue_payments")
def check_overdue_payments():
    db = SessionLocal()
    try:
        overdue_customers = db.execute(text("""
            SELECT c.customer_id, c.customer_name, c.current_balance, c.payment_terms,
                   si.invoice_number, si.invoice_date, si.remaining_amount
            FROM customers c
            JOIN sales_invoices si ON si.customer_id = c.customer_id
            WHERE si.payment_status != 'paid'
              AND c.payment_terms > 0
              AND (CURRENT_DATE - si.invoice_date::date) > c.payment_terms
            ORDER BY (CURRENT_DATE - si.invoice_date::date) DESC
        """)).fetchall()

        overdue_suppliers = db.execute(text("""
            SELECT s.supplier_id, s.supplier_name, s.current_balance, s.payment_terms,
                   pi.invoice_number, pi.purchase_date, pi.remaining_amount
            FROM suppliers s
            JOIN purchase_invoices pi ON pi.supplier_id = s.supplier_id
            WHERE pi.payment_status != 'paid'
              AND s.payment_terms > 0
              AND (CURRENT_DATE - pi.purchase_date::date) > s.payment_terms
            ORDER BY (CURRENT_DATE - pi.purchase_date::date) DESC
        """)).fetchall()

        return {
            "status": "success",
            "overdue_customers": len(overdue_customers),
            "overdue_suppliers": len(overdue_suppliers),
        }
    finally:
        db.close()


@celery_app.task(name="app.tasks.reports.generate_daily_report")
def generate_daily_report(report_date: str | None = None):
    db = SessionLocal()
    try:
        d = report_date or str(date.today() - timedelta(days=1))

        sales = db.execute(text("""
            SELECT COUNT(*) as count, COALESCE(SUM(total_amount), 0) as total
            FROM sales_invoices WHERE invoice_date::date = :d
        """), {"d": d}).fetchone()

        purchases = db.execute(text("""
            SELECT COUNT(*) as count, COALESCE(SUM(total_amount), 0) as total
            FROM purchase_invoices WHERE purchase_date::date = :d
        """), {"d": d}).fetchone()

        expenses_total = db.execute(text("""
            SELECT COALESCE(SUM(amount), 0) as total
            FROM expenses WHERE expense_date::date = :d
        """), {"d": d}).fetchone()

        payments_in = db.execute(text("""
            SELECT COALESCE(SUM(payment_amount), 0) as total
            FROM customer_payments WHERE payment_date::date = :d
        """), {"d": d}).fetchone()

        payments_out = db.execute(text("""
            SELECT COALESCE(SUM(payment_amount), 0) as total
            FROM supplier_payments WHERE payment_date::date = :d
        """), {"d": d}).fetchone()

        report = {
            "date": d,
            "sales_count": sales[0] if sales else 0,
            "sales_total": str(sales[1]) if sales else "0",
            "purchases_count": purchases[0] if purchases else 0,
            "purchases_total": str(purchases[1]) if purchases else "0",
            "expenses_total": str(expenses_total[0]) if expenses_total else "0",
            "customer_payments_received": str(payments_in[0]) if payments_in else "0",
            "supplier_payments_made": str(payments_out[0]) if payments_out else "0",
        }

        # Also refresh the financial summary for this date
        db.execute(text("SELECT fn_refresh_daily_financial_summary(:d)"), {"d": d})
        db.commit()

        return {"status": "success", "report": report}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()
