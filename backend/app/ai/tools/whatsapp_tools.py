"""WhatsApp Integration Layer using Meta Cloud API."""
import httpx
from datetime import date, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import text
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

    def send_report_to_owner(self, report_type: str = "daily_operations") -> dict:
        """Send any report type to the owner's WhatsApp number."""
        if not settings.whatsapp_can_send:
            return {"error": "WhatsApp sending is disabled."}

        owner_phone = settings.whatsapp_owner_phone
        if not owner_phone:
            return {"error": "Owner phone not configured. Set WHATSAPP_OWNER_PHONE in settings."}

        report_generators = {
            "daily_operations": self._gen_daily_operations,
            "daily_sales": self._gen_daily_sales,
            "monthly_profit": self._gen_monthly_profit,
            "top_products": self._gen_top_products,
            "low_stock": self._gen_low_stock,
            "cash_flow": self._gen_cash_flow,
            "customer_balances": self._gen_customer_balances,
            "supplier_balances": self._gen_supplier_balances,
            "profit_loss": self._gen_profit_loss,
            "expense_by_category": self._gen_expense_by_category,
            "inventory_valuation": self._gen_inventory_valuation,
            "dead_stock": self._gen_dead_stock,
            "stock_movement": self._gen_stock_movement,
        }

        generator = report_generators.get(report_type)
        if not generator:
            return {"error": f"Unknown report type: {report_type}. Available: {list(report_generators.keys())}"}

        try:
            message = generator()
            result = self.send_whatsapp_message(owner_phone, message)
            if "error" in result:
                return result
            return {"status": "sent", "report_type": report_type, "to": owner_phone}
        except Exception as e:
            logger.error(f"Report generation failed [{report_type}]: {e}")
            return {"error": f"Failed to generate report: {str(e)}"}

    def get_daily_operations_report(self) -> dict:
        """Get comprehensive daily operations data for voice readback."""
        today = date.today().isoformat()

        sales_q = text("""
            SELECT COUNT(id), COALESCE(SUM(total_amount),0), COALESCE(SUM(paid_amount),0),
                   COALESCE(SUM(CASE WHEN payment_type='cash' THEN total_amount ELSE 0 END),0),
                   COALESCE(SUM(CASE WHEN payment_type='credit' THEN total_amount ELSE 0 END),0)
            FROM sales_invoices WHERE DATE(created_at) = :today
        """)
        sr = self.db.execute(sales_q, {"today": today}).fetchone()
        sales_count, sales_total, sales_paid, sales_cash, sales_credit = sr if sr else (0,0,0,0,0)

        purchases_q = text("""
            SELECT COUNT(id), COALESCE(SUM(total_amount),0), COALESCE(SUM(paid_amount),0)
            FROM purchase_invoices WHERE DATE(created_at) = :today
        """)
        pr = self.db.execute(purchases_q, {"today": today}).fetchone()
        purch_count, purch_total, purch_paid = pr if pr else (0,0,0)

        expenses_q = text("""
            SELECT COUNT(id), COALESCE(SUM(amount),0)
            FROM expenses WHERE DATE(expense_date) = :today
        """)
        er = self.db.execute(expenses_q, {"today": today}).fetchone()
        exp_count, exp_total = er if er else (0,0)

        returns_q = text("""
            SELECT COUNT(id), COALESCE(SUM(total_amount),0)
            FROM sales_returns WHERE DATE(created_at) = :today
        """)
        rr = self.db.execute(returns_q, {"today": today}).fetchone()
        ret_count, ret_total = rr if rr else (0,0)

        total_in = float(sales_paid)
        total_out = float(purch_paid) + float(exp_total)
        net = total_in - total_out

        return {
            "report_date": today,
            "sales": {"count": sales_count, "total": float(sales_total), "cash": float(sales_cash), "credit": float(sales_credit)},
            "purchases": {"count": purch_count, "total": float(purch_total), "paid": float(purch_paid)},
            "expenses": {"count": exp_count, "total": float(exp_total)},
            "returns": {"count": ret_count, "total": float(ret_total)},
            "cash_position": {"total_in": total_in, "total_out": total_out, "net": net},
        }

    # === Report message generators ===

    def _gen_daily_operations(self) -> str:
        data = self.get_daily_operations_report()
        s = data["sales"]
        p = data["purchases"]
        e = data["expenses"]
        r = data["returns"]
        c = data["cash_position"]
        return (
            f"\U0001f4cb تقرير العمليات اليومية - {data['report_date']}\n"
            f"═══════════════════\n"
            f"\U0001f4b0 المبيعات: {s['count']} فاتورة | {s['total']:,.0f} جنيه\n"
            f"   نقدي: {s['cash']:,.0f} | آجل: {s['credit']:,.0f}\n"
            f"\U0001f6d2 المشتريات: {p['count']} | {p['total']:,.0f} جنيه\n"
            f"\U0001f4b8 المصروفات: {e['count']} | {e['total']:,.0f} جنيه\n"
            f"\U0001f504 المرتجعات: {r['count']} | {r['total']:,.0f} جنيه\n"
            f"═══════════════════\n"
            f"\U0001f4c8 إجمالي الوارد: {c['total_in']:,.0f} جنيه\n"
            f"\U0001f4c9 إجمالي الصادر: {c['total_out']:,.0f} جنيه\n"
            f"\U0001f4b5 صافي اليوم: {c['net']:,.0f} جنيه"
        )

    def _gen_daily_sales(self) -> str:
        today = date.today().isoformat()
        q = text("""
            SELECT COUNT(id), COALESCE(SUM(total_amount),0), COALESCE(SUM(paid_amount),0)
            FROM sales_invoices WHERE DATE(created_at) = :today
        """)
        row = self.db.execute(q, {"today": today}).fetchone()
        cnt, total, paid = row if row else (0,0,0)
        return (
            f"\U0001f4ca المبيعات اليومية - {today}\n"
            f"عدد الفواتير: {cnt}\n"
            f"إجمالي المبيعات: {total:,.0f} جنيه\n"
            f"المحصل: {paid:,.0f} جنيه"
        )

    def _gen_monthly_profit(self) -> str:
        q = text("""
            SELECT COALESCE(SUM(revenue),0), COALESCE(SUM(cogs),0),
                   COALESCE(SUM(expenses),0), COALESCE(SUM(net_profit),0)
            FROM daily_financial_summary
            WHERE EXTRACT(MONTH FROM summary_date) = EXTRACT(MONTH FROM CURRENT_DATE)
              AND EXTRACT(YEAR FROM summary_date) = EXTRACT(YEAR FROM CURRENT_DATE)
        """)
        row = self.db.execute(q).fetchone()
        rev, cogs, exp, profit = row if row else (0,0,0,0)
        return (
            f"\U0001f4b0 أرباح الشهر الحالي\n"
            f"الإيرادات: {rev:,.0f} جنيه\n"
            f"تكلفة البضاعة: {cogs:,.0f} جنيه\n"
            f"المصروفات: {exp:,.0f} جنيه\n"
            f"صافي الربح: {profit:,.0f} جنيه"
        )

    def _gen_top_products(self) -> str:
        q = text("""
            SELECT p.product_name, SUM(sii.sold_quantity) as qty, SUM(sii.total_price) as rev
            FROM sales_invoice_items sii
            JOIN products p ON p.product_id = sii.product_id
            JOIN sales_invoices si ON si.invoice_id = sii.invoice_id
            WHERE si.created_at >= CURRENT_DATE - INTERVAL '30 days'
            GROUP BY p.product_name ORDER BY rev DESC LIMIT 5
        """)
        rows = self.db.execute(q).fetchall()
        lines = [f"\U0001f3c6 أفضل المنتجات (30 يوم)"]
        for i, (name, qty, rev) in enumerate(rows, 1):
            lines.append(f"{i}. {name}: {qty:.0f} قطعة | {rev:,.0f} جنيه")
        return "\n".join(lines) if rows else "لا توجد بيانات"

    def _gen_low_stock(self) -> str:
        q = text("""
            SELECT p.product_name, COALESCE(SUM(ic.cached_quantity),0) as stock
            FROM products p
            LEFT JOIN inventory_cache ic ON ic.product_id = p.product_id
            GROUP BY p.product_name
            HAVING COALESCE(SUM(ic.cached_quantity),0) <= 10
            ORDER BY stock ASC LIMIT 10
        """)
        rows = self.db.execute(q).fetchall()
        lines = [f"⚠️ منتجات قاربت على النفاد"]
        for name, stock in rows:
            lines.append(f"• {name}: {stock:.0f}")
        return "\n".join(lines) if rows else "لا توجد منتجات منخفضة المخزون"

    def _gen_cash_flow(self) -> str:
        q = text("""
            SELECT COALESCE(SUM(revenue),0), COALESCE(SUM(cogs),0), COALESCE(SUM(expenses),0)
            FROM daily_financial_summary
            WHERE summary_date >= CURRENT_DATE - INTERVAL '7 days'
        """)
        row = self.db.execute(q).fetchone()
        rev, cogs, exp = row if row else (0,0,0)
        return (
            f"\U0001f4b5 التدفق النقدي (7 أيام)\n"
            f"الوارد: {rev:,.0f} جنيه\n"
            f"الصادر: {float(cogs)+float(exp):,.0f} جنيه\n"
            f"الصافي: {float(rev)-float(cogs)-float(exp):,.0f} جنيه"
        )

    def _gen_customer_balances(self) -> str:
        q = text("""
            SELECT name, current_balance FROM customers
            WHERE current_balance > 0 ORDER BY current_balance DESC LIMIT 10
        """)
        rows = self.db.execute(q).fetchall()
        lines = [f"\U0001f4cb أرصدة العملاء (أعلى 10)"]
        for name, bal in rows:
            lines.append(f"• {name}: {bal:,.0f} جنيه")
        return "\n".join(lines) if rows else "لا توجد أرصدة مستحقة"

    def _gen_supplier_balances(self) -> str:
        q = text("""
            SELECT name, current_balance FROM suppliers
            WHERE current_balance > 0 ORDER BY current_balance DESC LIMIT 10
        """)
        rows = self.db.execute(q).fetchall()
        lines = [f"\U0001f4cb أرصدة الموردين (أعلى 10)"]
        for name, bal in rows:
            lines.append(f"• {name}: {bal:,.0f} جنيه")
        return "\n".join(lines) if rows else "لا توجد أرصدة للموردين"

    def _gen_profit_loss(self) -> str:
        q = text("""
            SELECT COALESCE(SUM(revenue),0), COALESCE(SUM(cogs),0),
                   COALESCE(SUM(expenses),0), COALESCE(SUM(net_profit),0)
            FROM daily_financial_summary
            WHERE summary_date >= CURRENT_DATE - INTERVAL '30 days'
        """)
        row = self.db.execute(q).fetchone()
        rev, cogs, exp, profit = row if row else (0,0,0,0)
        margin = (float(profit)/float(rev)*100) if float(rev) > 0 else 0
        return (
            f"\U0001f4ca الأرباح والخسائر (30 يوم)\n"
            f"الإيرادات: {rev:,.0f} جنيه\n"
            f"تكلفة البضاعة: {cogs:,.0f} جنيه\n"
            f"المصروفات: {exp:,.0f} جنيه\n"
            f"صافي الربح: {profit:,.0f} جنيه\n"
            f"هامش الربح: {margin:.1f}%"
        )

    def _gen_expense_by_category(self) -> str:
        q = text("""
            SELECT category, SUM(amount) as total
            FROM expenses
            WHERE expense_date >= CURRENT_DATE - INTERVAL '30 days'
            GROUP BY category ORDER BY total DESC
        """)
        rows = self.db.execute(q).fetchall()
        lines = [f"\U0001f4b8 المصروفات حسب الفئة (30 يوم)"]
        for cat, total in rows:
            lines.append(f"• {cat}: {total:,.0f} جنيه")
        return "\n".join(lines) if rows else "لا توجد مصروفات"

    def _gen_inventory_valuation(self) -> str:
        q = text("""
            SELECT COALESCE(SUM(ic.cached_quantity * p.cost_price),0)
            FROM inventory_cache ic
            JOIN products p ON p.product_id = ic.product_id
        """)
        total = self.db.execute(q).scalar() or 0
        return f"\U0001f4e6 قيمة المخزون الحالي: {total:,.0f} جنيه"

    def _gen_dead_stock(self) -> str:
        q = text("""
            SELECT p.product_name, COALESCE(SUM(ic.cached_quantity),0) as stock
            FROM products p
            JOIN inventory_cache ic ON ic.product_id = p.product_id
            LEFT JOIN sales_invoice_items sii ON sii.product_id = p.product_id
            LEFT JOIN sales_invoices si ON si.invoice_id = sii.invoice_id
                AND si.created_at >= CURRENT_DATE - INTERVAL '30 days'
            GROUP BY p.product_name
            HAVING COALESCE(SUM(ic.cached_quantity),0) > 0
               AND COUNT(si.invoice_id) = 0
            ORDER BY stock DESC LIMIT 10
        """)
        rows = self.db.execute(q).fetchall()
        lines = [f"\U0001f6ab مخزون راكد (لم يُباع 30 يوم)"]
        for name, stock in rows:
            lines.append(f"• {name}: {stock:.0f}")
        return "\n".join(lines) if rows else "لا يوجد مخزون راكد"

    def _gen_stock_movement(self) -> str:
        q = text("""
            SELECT 
                COALESCE(SUM(CASE WHEN transaction_type='purchase' THEN quantity ELSE 0 END),0) as purchased,
                COALESCE(SUM(CASE WHEN transaction_type='sale' THEN quantity ELSE 0 END),0) as sold,
                COALESCE(SUM(CASE WHEN transaction_type='return' THEN quantity ELSE 0 END),0) as returned
            FROM inventory_transactions
            WHERE DATE(created_at) = CURRENT_DATE
        """)
        row = self.db.execute(q).fetchone()
        purchased, sold, returned = row if row else (0,0,0)
        return (
            f"\U0001f4e6 حركة المخزون اليوم\n"
            f"وارد (مشتريات): {purchased:.0f}\n"
            f"صادر (مبيعات): {sold:.0f}\n"
            f"مرتجع: {returned:.0f}"
        )
