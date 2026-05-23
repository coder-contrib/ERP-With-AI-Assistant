from app.celery_app import celery_app
from app.database import SessionLocal
from app.services.notification_service import NotificationService


@celery_app.task(name="app.tasks.notifications.check_all_alerts")
def check_all_alerts():
    db = SessionLocal()
    try:
        service = NotificationService(db)
        low_stock = service.check_low_stock()
        credit = service.check_credit_limit_exceeded()
        overdue = service.check_overdue_supplier_payments()
        return {
            "status": "success",
            "low_stock_alerts": low_stock,
            "credit_limit_exceeded": credit,
            "overdue_supplier_payments": overdue,
        }
    finally:
        db.close()


@celery_app.task(name="app.tasks.notifications.daily_closing_reminder")
def daily_closing_reminder():
    db = SessionLocal()
    try:
        service = NotificationService(db)
        service.create_daily_closing_reminder()
        db.commit()
        return {"status": "success", "detail": "Daily closing reminder created"}
    finally:
        db.close()
