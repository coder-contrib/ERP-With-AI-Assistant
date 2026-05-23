from fastapi import APIRouter, Depends
from app.core.deps import require_admin
from app.models.users import User
from app.tasks.accounting import refresh_daily_summary, refresh_summary_range, recalculate_all_balances
from app.tasks.inventory import refresh_inventory_cache, check_low_stock
from app.tasks.reports import generate_daily_report, check_overdue_payments

router = APIRouter()


@router.post("/refresh-daily-summary")
def trigger_refresh_daily_summary(target_date: str | None = None, current_user: User = Depends(require_admin)):
    task = refresh_daily_summary.delay(target_date)
    return {"detail": "Task queued", "task_id": task.id}


@router.post("/refresh-summary-range")
def trigger_refresh_summary_range(start_date: str, end_date: str | None = None, current_user: User = Depends(require_admin)):
    task = refresh_summary_range.delay(start_date, end_date)
    return {"detail": "Task queued", "task_id": task.id}


@router.post("/recalculate-balances")
def trigger_recalculate_balances(current_user: User = Depends(require_admin)):
    task = recalculate_all_balances.delay()
    return {"detail": "Task queued", "task_id": task.id}


@router.post("/refresh-inventory-cache")
def trigger_refresh_inventory(current_user: User = Depends(require_admin)):
    task = refresh_inventory_cache.delay()
    return {"detail": "Task queued", "task_id": task.id}


@router.post("/check-low-stock")
def trigger_check_low_stock(threshold: float = 10.0, current_user: User = Depends(require_admin)):
    task = check_low_stock.delay(threshold)
    return {"detail": "Task queued", "task_id": task.id}


@router.post("/generate-daily-report")
def trigger_daily_report(report_date: str | None = None, current_user: User = Depends(require_admin)):
    task = generate_daily_report.delay(report_date)
    return {"detail": "Task queued", "task_id": task.id}


@router.post("/check-overdue-payments")
def trigger_check_overdue(current_user: User = Depends(require_admin)):
    task = check_overdue_payments.delay()
    return {"detail": "Task queued", "task_id": task.id}


@router.get("/task-status/{task_id}")
def get_task_status(task_id: str, current_user: User = Depends(require_admin)):
    from app.celery_app import celery_app
    result = celery_app.AsyncResult(task_id)
    return {
        "task_id": task_id,
        "status": result.status,
        "result": result.result if result.ready() else None,
    }
