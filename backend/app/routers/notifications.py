from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.core.deps import get_current_user
from app.models.users import User
from app.services.notification_service import NotificationService
from app.schemas.notifications import NotificationResponse

router = APIRouter()


@router.get("/", response_model=list[NotificationResponse])
def list_notifications(limit: int = 50, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = NotificationService(db)
    return service.get_all(user_id=current_user.user_id, limit=limit)


@router.get("/unread", response_model=list[NotificationResponse])
def get_unread_notifications(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = NotificationService(db)
    return service.get_unread(user_id=current_user.user_id)


@router.get("/unread/count")
def get_unread_count(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = NotificationService(db)
    notifications = service.get_unread(user_id=current_user.user_id)
    return {"unread_count": len(notifications)}


@router.put("/{notification_id}/read")
def mark_notification_read(notification_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = NotificationService(db)
    service.mark_read(notification_id)
    return {"detail": "Notification marked as read"}


@router.put("/read-all")
def mark_all_read(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = NotificationService(db)
    service.mark_all_read(user_id=current_user.user_id)
    return {"detail": "All notifications marked as read"}


@router.post("/check")
def run_notification_checks(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = NotificationService(db)
    low_stock = service.check_low_stock()
    credit = service.check_credit_limit_exceeded()
    overdue = service.check_overdue_supplier_payments()
    return {
        "new_notifications": {
            "low_stock_alerts": low_stock,
            "credit_limit_exceeded": credit,
            "overdue_supplier_payments": overdue,
        }
    }
