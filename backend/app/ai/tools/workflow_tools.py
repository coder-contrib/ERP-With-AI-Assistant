"""Composite Workflow Tools.

These combine multiple atomic operations into guaranteed business workflows.
The AI calls ONE tool instead of chaining multiple tools manually.
"""
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.ai.tools.action_tools import ActionTools
from app.ai.tools.whatsapp_tools import WhatsAppTools
import logging

logger = logging.getLogger(__name__)


class WorkflowTools:
    def __init__(self, db: Session):
        self.db = db
        self.actions = ActionTools(db)
        self.whatsapp = WhatsAppTools(db)

    def create_invoice_and_notify(self,
                                   customer_id: int,
                                   items: list,
                                   payment_type: str = "cash",
                                   warehouse_id: int = 1,
                                   discount: float = 0,
                                   paid_amount: float = None,
                                   notes: str = None,
                                   message_template: str = None) -> dict:
        # Step 1: Create the invoice
        invoice_result = self.actions.create_invoice(
            customer_id=customer_id,
            items=items,
            payment_type=payment_type,
            warehouse_id=warehouse_id,
            discount=discount,
            paid_amount=paid_amount,
            notes=notes,
        )

        if isinstance(invoice_result, dict) and "error" in invoice_result:
            return {"error": invoice_result["error"], "step_failed": "create_invoice"}

        invoice_id = invoice_result.get("invoice_id") or invoice_result.get("id")
        total = invoice_result.get("total", 0)

        # Step 2: Get customer phone
        phone = self._get_customer_phone(customer_id)
        if not phone:
            return {
                **invoice_result,
                "whatsapp_sent": False,
                "whatsapp_reason": "Customer has no phone number on file",
            }

        # Step 3: Build message
        customer_name = self._get_customer_name(customer_id)
        if message_template:
            message = message_template.format(
                customer_name=customer_name,
                invoice_id=invoice_id,
                total=f"{total:,.0f}",
                payment_type=payment_type,
            )
        else:
            item_count = len(items)
            message = (
                f"السلام عليكم {customer_name}،\n"
                f"تم إنشاء فاتورة رقم #{invoice_id}\n"
                f"───────────────\n"
                f"\U0001f4cb عدد الأصناف: {item_count}\n"
                f"\U0001f4b0 الإجمالي: {total:,.0f} جنيه\n"
                f"\U0001f4b3 طريقة الدفع: {self._translate_payment_type(payment_type)}\n"
                f"───────────────\n"
                f"شكراً لتعاملكم معنا \U0001f64f"
            )

        # Step 4: Send WhatsApp
        wa_result = self.whatsapp.send_whatsapp_message(phone, message)

        whatsapp_sent = "error" not in wa_result

        return {
            **invoice_result,
            "whatsapp_sent": whatsapp_sent,
            "whatsapp_to": phone,
            "whatsapp_message_id": wa_result.get("message_id") if whatsapp_sent else None,
            "whatsapp_error": wa_result.get("error") if not whatsapp_sent else None,
        }

    def _get_customer_phone(self, customer_id: int) -> str:
        if not customer_id:
            return ""
        row = self.db.execute(
            text("SELECT phone FROM customers WHERE id = :cid"),
            {"cid": customer_id},
        ).fetchone()
        return (row[0] or "").strip() if row else ""

    def _get_customer_name(self, customer_id: int) -> str:
        if not customer_id:
            return "عميل"
        row = self.db.execute(
            text("SELECT name FROM customers WHERE id = :cid"),
            {"cid": customer_id},
        ).fetchone()
        return row[0] if row else f"عميل #{customer_id}"

    def _translate_payment_type(self, payment_type: str) -> str:
        return {
            "cash": "نقدي",
            "credit": "آجل",
            "mixed": "جزئي",
        }.get(payment_type, payment_type)
