"""WhatsApp Integration Layer using Meta Cloud API."""
import httpx
from datetime import date, timedelta
from sqlalchemy.orm import Session
from app.config import settings
import logging

logger = logging.getLogger(__name__)

WHATSAPP_API_BASE = "https://graph.facebook.com/v18.0"


class WhatsAppTools:
    def __init__(self, db: Session):
        self.db = db
        self.api_token = settings.whatsapp_api_token
        self.phone_number_id = settings.whatsapp_phone_number_id

    def _send_template_message(self, to: str, template_name: str, language: str = "ar", components: list = None) -> dict:
        url = f"{WHATSAPP_API_BASE}/{self.phone_number_id}/messages"
        headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Content-Type": "application/json",
        }
        payload = {
            "messaging_product": "whatsapp",
            "to": to,
            "type": "template",
            "template": {
                "name": template_name,
                "language": {"code": language},
            },
        }
        if components:
            payload["template"]["components"] = components

        with httpx.Client(timeout=30) as client:
            resp = client.post(url, headers=headers, json=payload)
            resp.raise_for_status()
            return resp.json()

    def _send_text_message(self, to: str, body: str) -> dict:
        url = f"{WHATSAPP_API_BASE}/{self.phone_number_id}/messages"
        headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Content-Type": "application/json",
        }
        payload = {
            "messaging_product": "whatsapp",
            "to": to,
            "type": "text",
            "text": {"body": body},
        }

        with httpx.Client(timeout=30) as client:
            resp = client.post(url, headers=headers, json=payload)
            resp.raise_for_status()
            return resp.json()

    def send_whatsapp_message(self, to: str, message: str) -> dict:
        if not settings.whatsapp_can_send:
            return {"error": "WhatsApp sending is disabled. Enable WHATSAPP_CAN_SEND in settings."}

        if not self.api_token or not self.phone_number_id:
            return {"error": "WhatsApp API not configured. Set WHATSAPP_API_TOKEN and WHATSAPP_PHONE_NUMBER_ID."}

        to_clean = to.replace("+", "").replace(" ", "").replace("-", "")

        try:
            result = self._send_text_message(to_clean, message)
            message_id = result.get("messages", [{}])[0].get("id", "unknown")
            return {
                "status": "sent",
                "to": to_clean,
                "message_id": message_id,
                "message_preview": message[:100],
            }
        except httpx.HTTPStatusError as e:
            logger.error(f"WhatsApp API error: {e.response.status_code} - {e.response.text}")
            return {"error": f"WhatsApp API error: {e.response.status_code}", "details": e.response.text[:200]}
        except Exception as e:
            logger.error(f"WhatsApp send failed: {e}")
            return {"error": f"Failed to send WhatsApp message: {str(e)}"}

    def send_overdue_reminders(self) -> dict:
        if not settings.whatsapp_can_send:
            return {"error": "WhatsApp sending is disabled. Enable WHATSAPP_CAN_SEND in settings."}

        if not settings.whatsapp_can_bulk_message:
            return {"error": "Bulk WhatsApp messaging is disabled. Enable WHATSAPP_CAN_BULK_MESSAGE in settings."}

        from sqlalchemy import text

        query = text("""
            SELECT c.id, c.name, c.phone, 
                   SUM(si.total_amount - si.paid_amount) as total_due,
                   COUNT(si.id) as invoice_count
            FROM customers c
            JOIN sales_invoices si ON si.customer_id = c.id
            WHERE si.payment_status IN ('unpaid', 'partial')
              AND si.created_at < :cutoff_date
              AND c.phone IS NOT NULL
              AND c.phone != ''
            GROUP BY c.id, c.name, c.phone
            HAVING SUM(si.total_amount - si.paid_amount) > 0
            ORDER BY total_due DESC
            LIMIT :max_messages
        """)

        cutoff = (date.today() - timedelta(days=7)).isoformat()
        rows = self.db.execute(query, {
            "cutoff_date": cutoff,
            "max_messages": settings.whatsapp_max_messages_per_request,
        }).fetchall()

        if not rows:
            return {"status": "no_overdue", "message": "No overdue customers with phone numbers found."}

        sent = []
        failed = []

        for row in rows:
            customer_id, name, phone, total_due, invoice_count = row
            msg = (
                f"السلام عليكم {name}،\n"
                f"نذكركم برصيد مستحق بقيمة {total_due:.0f} جنيه ({invoice_count} فاتورة).\n"
                f"نرجو التواصل لترتيب السداد. شكراً لكم."
            )
            result = self.send_whatsapp_message(phone, msg)
            if "error" in result:
                failed.append({"customer_id": customer_id, "name": name, "error": result["error"]})
            else:
                sent.append({"customer_id": customer_id, "name": name, "amount_due": total_due})

        return {
            "status": "completed",
            "sent_count": len(sent),
            "failed_count": len(failed),
            "sent": sent,
            "failed": failed,
        }

    def send_daily_sales_report(self, to: str) -> dict:
        if not settings.whatsapp_can_send:
            return {"error": "WhatsApp sending is disabled. Enable WHATSAPP_CAN_SEND in settings."}

        from sqlalchemy import text

        today = date.today().isoformat()
        query = text("""
            SELECT 
                COUNT(id) as invoice_count,
                COALESCE(SUM(total_amount), 0) as total_revenue,
                COALESCE(SUM(paid_amount), 0) as cash_collected
            FROM sales_invoices
            WHERE DATE(created_at) = :today
        """)
        row = self.db.execute(query, {"today": today}).fetchone()
        invoice_count, total_revenue, cash_collected = row if row else (0, 0, 0)

        expense_query = text("""
            SELECT COALESCE(SUM(amount), 0)
            FROM expenses
            WHERE DATE(expense_date) = :today
        """)
        total_expenses = self.db.execute(expense_query, {"today": today}).scalar() or 0

        report = (
            f"\U0001f4ca تقرير المبيعات اليومي - {today}\n"
            f"───────────────\n"
            f"\U0001f4cb عدد الفواتير: {invoice_count}\n"
            f"\U0001f4b0 إجمالي المبيعات: {total_revenue:,.0f} جنيه\n"
            f"\U0001f4b5 النقدي المحصل: {cash_collected:,.0f} جنيه\n"
            f"\U0001f4c9 المصروفات: {total_expenses:,.0f} جنيه\n"
            f"───────────────\n"
            f"\U0001f4c8 صافي: {total_revenue - total_expenses:,.0f} جنيه"
        )

        result = self.send_whatsapp_message(to, report)
        if "error" in result:
            return result

        return {
            "status": "sent",
            "to": to,
            "report_summary": {
                "date": today,
                "invoices": invoice_count,
                "revenue": float(total_revenue),
                "cash_collected": float(cash_collected),
                "expenses": float(total_expenses),
                "net": float(total_revenue - total_expenses),
            },
        }
