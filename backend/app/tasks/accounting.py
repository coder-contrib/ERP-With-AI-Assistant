from app.celery_app import celery_app
from app.database import SessionLocal
from sqlalchemy import text
from datetime import date, timedelta


@celery_app.task(name="app.tasks.accounting.refresh_daily_summary")
def refresh_daily_summary(target_date: str | None = None):
    db = SessionLocal()
    try:
        d = target_date or str(date.today())
        db.execute(text("SELECT fn_refresh_daily_financial_summary(:d)"), {"d": d})
        db.commit()
        return {"status": "success", "date": d}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()


@celery_app.task(name="app.tasks.accounting.refresh_summary_range")
def refresh_summary_range(start_date: str, end_date: str | None = None):
    db = SessionLocal()
    try:
        end = end_date or str(date.today())
        db.execute(
            text("SELECT fn_refresh_financial_summary_range(:s, :e)"),
            {"s": start_date, "e": end},
        )
        db.commit()
        return {"status": "success", "start": start_date, "end": end}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()


@celery_app.task(name="app.tasks.accounting.recalculate_all_balances")
def recalculate_all_balances():
    db = SessionLocal()
    try:
        db.execute(text("""
            UPDATE customers c SET current_balance = COALESCE((
                SELECT SUM(si.remaining_amount)
                FROM sales_invoices si
                WHERE si.customer_id = c.customer_id AND si.payment_status != 'paid'
            ), 0)
        """))
        db.execute(text("""
            UPDATE suppliers s SET current_balance = COALESCE((
                SELECT SUM(pi.remaining_amount)
                FROM purchase_invoices pi
                WHERE pi.supplier_id = s.supplier_id AND pi.payment_status != 'paid'
            ), 0)
        """))
        db.commit()
        return {"status": "success", "detail": "All balances recalculated"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()
