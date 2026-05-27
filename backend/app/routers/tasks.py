from fastapi import APIRouter, Depends
from app.core.deps import require_admin
from app.models.users import User

router = APIRouter()


def _get_celery():
    from app.celery_app import celery_app
    return celery_app


@router.post("/refresh-daily-summary")
def trigger_refresh_daily_summary(target_date: str | None = None, current_user: User = Depends(require_admin)):
    task = _get_celery().send_task("app.tasks.accounting.refresh_daily_summary", args=[target_date])
    return {"detail": "Task queued", "task_id": task.id}


@router.post("/refresh-summary-range")
def trigger_refresh_summary_range(start_date: str, end_date: str | None = None, current_user: User = Depends(require_admin)):
    task = _get_celery().send_task("app.tasks.accounting.refresh_summary_range", args=[start_date, end_date])
    return {"detail": "Task queued", "task_id": task.id}


@router.post("/recalculate-balances")
def trigger_recalculate_balances(current_user: User = Depends(require_admin)):
    task = _get_celery().send_task("app.tasks.accounting.recalculate_all_balances")
    return {"detail": "Task queued", "task_id": task.id}


@router.post("/refresh-inventory-cache")
def trigger_refresh_inventory(current_user: User = Depends(require_admin)):
    task = _get_celery().send_task("app.tasks.inventory.refresh_inventory_cache")
    return {"detail": "Task queued", "task_id": task.id}


@router.post("/check-low-stock")
def trigger_check_low_stock(threshold: float = 10.0, current_user: User = Depends(require_admin)):
    task = _get_celery().send_task("app.tasks.inventory.check_low_stock", args=[threshold])
    return {"detail": "Task queued", "task_id": task.id}


@router.post("/generate-daily-report")
def trigger_daily_report(report_date: str | None = None, current_user: User = Depends(require_admin)):
    task = _get_celery().send_task("app.tasks.reports.generate_daily_report", args=[report_date])
    return {"detail": "Task queued", "task_id": task.id}


@router.post("/check-overdue-payments")
def trigger_check_overdue(current_user: User = Depends(require_admin)):
    task = _get_celery().send_task("app.tasks.reports.check_overdue_payments")
    return {"detail": "Task queued", "task_id": task.id}


@router.get("/task-status/{task_id}")
def get_task_status(task_id: str, current_user: User = Depends(require_admin)):
    result = _get_celery().AsyncResult(task_id)
    return {
        "task_id": task_id,
        "status": result.status,
        "result": result.result if result.ready() else None,
    }
