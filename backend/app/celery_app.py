from celery import Celery
from celery.schedules import crontab
from app.config import settings

celery_app = Celery(
    "ceramic_erp",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
)

celery_app.conf.beat_schedule = {
    "refresh-daily-financial-summary": {
        "task": "app.tasks.accounting.refresh_daily_summary",
        "schedule": crontab(hour=23, minute=55),
    },
    "refresh-inventory-cache": {
        "task": "app.tasks.inventory.refresh_inventory_cache",
        "schedule": crontab(hour="*/4", minute=0),
    },
    "check-overdue-payments": {
        "task": "app.tasks.reports.check_overdue_payments",
        "schedule": crontab(hour=8, minute=0),
    },
    "generate-daily-report": {
        "task": "app.tasks.reports.generate_daily_report",
        "schedule": crontab(hour=0, minute=5),
    },
    "check-all-alerts": {
        "task": "app.tasks.notifications.check_all_alerts",
        "schedule": crontab(hour="*/2", minute=30),
    },
    "daily-closing-reminder": {
        "task": "app.tasks.notifications.daily_closing_reminder",
        "schedule": crontab(hour=21, minute=0),
    },
}

celery_app.conf.include = [
    "app.tasks.notifications",
    "app.tasks.accounting",
    "app.tasks.inventory",
    "app.tasks.reports",
    "app.tasks.ai",
]
