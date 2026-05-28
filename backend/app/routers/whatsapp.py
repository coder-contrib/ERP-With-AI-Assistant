from fastapi import APIRouter, Depends, Body
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from app.database import get_db
from app.core.deps import require_permission
from app.models.users import User
from app.config import settings
from app.ai.tools.whatsapp_tools import WhatsAppTools

router = APIRouter()


class SendMessageRequest(BaseModel):
    to: str
    message: str


class SendDailyReportRequest(BaseModel):
    to: str


class UpdateSettingsRequest(BaseModel):
    whatsapp_api_token: str | None = None
    whatsapp_phone_number_id: str | None = None
    whatsapp_owner_phone: str | None = None
    whatsapp_can_send: bool | None = None
    whatsapp_can_bulk_message: bool | None = None
    whatsapp_max_messages_per_request: int | None = None


@router.get("/settings")
def get_whatsapp_settings(
    current_user: User = Depends(require_permission("admin:read")),
):
    return {
        "configured": bool(settings.whatsapp_api_token and settings.whatsapp_phone_number_id),
        "can_send": settings.whatsapp_can_send,
        "can_bulk_message": settings.whatsapp_can_bulk_message,
        "max_messages_per_request": settings.whatsapp_max_messages_per_request,
        "phone_number_id": settings.whatsapp_phone_number_id[:6] + "..." if settings.whatsapp_phone_number_id else "",
        "owner_phone": settings.whatsapp_owner_phone[:6] + "..." if settings.whatsapp_owner_phone else "",
        "api_token_set": bool(settings.whatsapp_api_token),
    }


@router.post("/settings")
def update_whatsapp_settings(
    body: UpdateSettingsRequest,
    current_user: User = Depends(require_permission("admin:write")),
):
    if body.whatsapp_api_token is not None:
        settings.whatsapp_api_token = body.whatsapp_api_token
    if body.whatsapp_phone_number_id is not None:
        settings.whatsapp_phone_number_id = body.whatsapp_phone_number_id
    if body.whatsapp_owner_phone is not None:
        settings.whatsapp_owner_phone = body.whatsapp_owner_phone
    if body.whatsapp_can_send is not None:
        settings.whatsapp_can_send = body.whatsapp_can_send
    if body.whatsapp_can_bulk_message is not None:
        settings.whatsapp_can_bulk_message = body.whatsapp_can_bulk_message
    if body.whatsapp_max_messages_per_request is not None:
        settings.whatsapp_max_messages_per_request = body.whatsapp_max_messages_per_request

    return {"status": "updated", "can_send": settings.whatsapp_can_send}


@router.post("/send")
def send_whatsapp_message(
    body: SendMessageRequest,
    current_user: User = Depends(require_permission("admin:write")),
    db: Session = Depends(get_db),
):
    tools = WhatsAppTools(db)
    result = tools.send_whatsapp_message(body.to, body.message)
    return result


@router.post("/send-overdue-reminders")
def send_overdue_reminders(
    current_user: User = Depends(require_permission("admin:write")),
    db: Session = Depends(get_db),
):
    tools = WhatsAppTools(db)
    result = tools.send_overdue_reminders()
    return result


@router.post("/send-daily-report")
def send_daily_report(
    body: SendDailyReportRequest,
    current_user: User = Depends(require_permission("admin:write")),
    db: Session = Depends(get_db),
):
    tools = WhatsAppTools(db)
    result = tools.send_daily_sales_report(body.to)
    return result


@router.post("/send-report-to-owner")
def send_report_to_owner(
    current_user: User = Depends(require_permission("admin:read")),
    db: Session = Depends(get_db),
):
    if not settings.whatsapp_owner_phone:
        return {"error": "Owner phone number not configured. Set WHATSAPP_OWNER_PHONE in settings."}

    tools = WhatsAppTools(db)
    result = tools.send_daily_sales_report(settings.whatsapp_owner_phone)
    return result


@router.post("/send-invoice/{invoice_id}")
def send_invoice_via_whatsapp(
    invoice_id: int,
    current_user: User = Depends(require_permission("sales:write")),
    db: Session = Depends(get_db),
):
    query = text("""
        SELECT si.id, si.total_amount, si.paid_amount, si.payment_status, 
               c.name, c.phone
        FROM sales_invoices si
        LEFT JOIN customers c ON c.id = si.customer_id
        WHERE si.id = :invoice_id
    """)
    row = db.execute(query, {"invoice_id": invoice_id}).fetchone()
    if not row:
        return {"error": "Invoice not found"}

    inv_id, total, paid, status, customer_name, customer_phone = row

    if not customer_phone:
        return {"error": "Customer does not have a phone number on file. Update the customer record first."}

    remaining = float(total) - float(paid)

    msg = (
        f"\U0001f4c4 فاتورة #{inv_id}\n"
        f"العميل: {customer_name or 'عميل نقدي'}\n"
        f"الإجمالي: {float(total):,.0f} جنيه\n"
        f"المدفوع: {float(paid):,.0f} جنيه\n"
    )
    if remaining > 0:
        msg += f"المتبقي: {remaining:,.0f} جنيه\n"
    msg += f"الحالة: {status}\nشكراً لتعاملكم معنا."

    tools = WhatsAppTools(db)
    result = tools.send_whatsapp_message(customer_phone, msg)
    result["invoice_id"] = inv_id
    result["sent_to_customer"] = customer_name
    return result
