from pydantic import BaseModel
from datetime import datetime


class NotificationResponse(BaseModel):
    notification_id: int
    user_id: int | None
    notification_type: str
    severity: str
    title: str
    message: str
    is_read: bool
    created_date: datetime | None

    class Config:
        from_attributes = True
