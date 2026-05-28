from fastapi import APIRouter, Depends, Body
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from datetime import date, timedelta
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


class SendReportToOwnerRequest(BaseModel):
    report_type: str = "daily_sales"


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
    body: SendReportToOwnerRequest = SendReportToOwnerRequest(),
    current_user: User = Depends(require_permission("admin:read")),
    db: Session = Depends(get_db),
):
    if not settings.whatsapp_owner_phone:
        return {"error": "Owner phone number not configured. Go to WhatsApp Settings and set your phone number."}

    report_type = body.report_type
    msg = _generate_report_message(db, report_type)

    if msg is None:
        return {"error": f"Unknown report type: {report_type}"}

    tools = WhatsAppTools(db)
    result = tools.send_whatsapp_message(settings.whatsapp_owner_phone, msg)
    result["report_type"] = report_type
    return result


def _generate_report_message(db: Session, report_type: str) -> str | None:
    today = date.today().isoformat()

    if report_type == "daily_operations":
        # Sales
        sales_row = db.execute(text("""
            SELECT COUNT(id), COALESCE(SUM(total_amount), 0), COALESCE(SUM(paid_amount), 0)
            FROM sales_invoices WHERE DATE(created_at) = :today
        """), {"today": today}).fetchone()
        sales_count, sales_total, sales_paid = sales_row if sales_row else (0, 0, 0)

        # Sales by type
        cash_sales = db.execute(text("""
            SELECT COALESCE(SUM(total_amount), 0) FROM sales_invoices
            WHERE DATE(created_at) = :today AND invoice_type = 'cash'
        """), {"today": today}).scalar() or 0
        credit_sales = db.execute(text("""
            SELECT COALESCE(SUM(total_amount), 0) FROM sales_invoices
            WHERE DATE(created_at) = :today AND invoice_type = 'credit'
        """), {"today": today}).scalar() or 0

        # Purchases
        purchases_row = db.execute(text("""
            SELECT COUNT(id), COALESCE(SUM(total_amount), 0), COALESCE(SUM(paid_amount), 0)
            FROM purchase_invoices WHERE DATE(created_at) = :today
        """), {"today": today}).fetchone()
        purch_count, purch_total, purch_paid = purchases_row if purchases_row else (0, 0, 0)

        # Expenses
        expenses_row = db.execute(text("""
            SELECT COUNT(id), COALESCE(SUM(amount), 0)
            FROM expenses WHERE DATE(expense_date) = :today
        """), {"today": today}).fetchone()
        exp_count, exp_total = expenses_row if expenses_row else (0, 0)

        # Returns (sales returns/cancelled)
        returns_row = db.execute(text("""
            SELECT COUNT(id), COALESCE(SUM(total_amount), 0)
            FROM sales_invoices WHERE DATE(created_at) = :today AND status = 'cancelled'
        """), {"today": today}).fetchone()
        ret_count, ret_total = returns_row if returns_row else (0, 0)

        # Payments received today (from older invoices)
        payments_received = db.execute(text("""
            SELECT COALESCE(SUM(amount), 0)
            FROM payments WHERE DATE(created_at) = :today AND type = 'incoming'
        """), {"today": today}).scalar() or 0

        # Payments made today (to suppliers)
        payments_made = db.execute(text("""
            SELECT COALESCE(SUM(amount), 0)
            FROM payments WHERE DATE(created_at) = :today AND type = 'outgoing'
        """), {"today": today}).scalar() or 0

        # New customers today
        new_customers = db.execute(text("""
            SELECT COUNT(id) FROM customers WHERE DATE(created_at) = :today
        """), {"today": today}).scalar() or 0

        # Items sold today
        items_sold = db.execute(text("""
            SELECT COALESCE(SUM(si.quantity), 0)
            FROM sale_items si
            JOIN sales_invoices inv ON inv.id = si.invoice_id
            WHERE DATE(inv.created_at) = :today
        """), {"today": today}).scalar() or 0

        # Net cash position
        total_in = float(sales_paid) + float(payments_received)
        total_out = float(purch_paid) + float(exp_total) + float(payments_made)
        net_cash = total_in - total_out

        return (
            f"\U0001f4cb ملخص العمليات اليومية الشامل\n"
            f"\U0001f4c5 {today}\n"
            f"═══════════════════\n\n"
            f"\U0001f4b0 المبيعات\n"
            f"───────────────\n"
            f"عدد الفواتير: {sales_count}\n"
            f"إجمالي المبيعات: {float(sales_total):,.0f} جنيه\n"
            f"  • نقدي: {float(cash_sales):,.0f} جنيه\n"
            f"  • آجل: {float(credit_sales):,.0f} جنيه\n"
            f"المحصل: {float(sales_paid):,.0f} جنيه\n"
            f"قطع مباعة: {int(items_sold)}\n\n"
            f"\U0001f6d2 المشتريات\n"
            f"───────────────\n"
            f"عدد الفواتير: {purch_count}\n"
            f"إجمالي المشتريات: {float(purch_total):,.0f} جنيه\n"
            f"المدفوع للموردين: {float(purch_paid):,.0f} جنيه\n\n"
            f"\U0001f4c9 المصروفات\n"
            f"───────────────\n"
            f"عدد المصروفات: {exp_count}\n"
            f"إجمالي المصروفات: {float(exp_total):,.0f} جنيه\n\n"
            f"\U0001f504 المرتجعات\n"
            f"───────────────\n"
            f"عدد المرتجعات: {ret_count}\n"
            f"قيمة المرتجعات: {float(ret_total):,.0f} جنيه\n\n"
            f"\U0001f4b3 التحصيلات والمدفوعات\n"
            f"───────────────\n"
            f"تحصيلات واردة: {float(payments_received):,.0f} جنيه\n"
            f"مدفوعات صادرة: {float(payments_made):,.0f} جنيه\n\n"
            f"\U0001f465 العملاء الجدد: {new_customers}\n\n"
            f"═══════════════════\n"
            f"\U0001f4b5 الخزينة اليوم\n"
            f"───────────────\n"
            f"إجمالي الداخل: {total_in:,.0f} جنيه\n"
            f"إجمالي الخارج: {total_out:,.0f} جنيه\n"
            f"{'✅' if net_cash >= 0 else '⚠️'} صافي اليوم: {net_cash:,.0f} جنيه"
        )

    elif report_type == "daily_sales":
        row = db.execute(text("""
            SELECT COUNT(id), COALESCE(SUM(total_amount), 0), COALESCE(SUM(paid_amount), 0)
            FROM sales_invoices WHERE DATE(created_at) = :today
        """), {"today": today}).fetchone()
        count, total, paid = row if row else (0, 0, 0)
        expenses = db.execute(text("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE DATE(expense_date) = :today"), {"today": today}).scalar() or 0
        return (
            f"\U0001f4ca تقرير المبيعات اليومي - {today}\n"
            f"───────────────\n"
            f"\U0001f4cb عدد الفواتير: {count}\n"
            f"\U0001f4b0 إجمالي المبيعات: {float(total):,.0f} جنيه\n"
            f"\U0001f4b5 النقدي المحصل: {float(paid):,.0f} جنيه\n"
            f"\U0001f4c9 المصروفات: {float(expenses):,.0f} جنيه\n"
            f"───────────────\n"
            f"\U0001f4c8 صافي: {float(total) - float(expenses):,.0f} جنيه"
        )

    elif report_type == "monthly_profit":
        first_of_month = date.today().replace(day=1).isoformat()
        row = db.execute(text("""
            SELECT COALESCE(SUM(total_amount), 0), COALESCE(SUM(paid_amount), 0), COUNT(id)
            FROM sales_invoices WHERE DATE(created_at) >= :start
        """), {"start": first_of_month}).fetchone()
        total, paid, count = row if row else (0, 0, 0)
        expenses = db.execute(text("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE DATE(expense_date) >= :start"), {"start": first_of_month}).scalar() or 0
        return (
            f"\U0001f4c8 تقرير الأرباح الشهري\n"
            f"من {first_of_month} إلى {today}\n"
            f"───────────────\n"
            f"\U0001f4cb عدد الفواتير: {count}\n"
            f"\U0001f4b0 إجمالي المبيعات: {float(total):,.0f} جنيه\n"
            f"\U0001f4b5 المحصل: {float(paid):,.0f} جنيه\n"
            f"\U0001f4c9 المصروفات: {float(expenses):,.0f} جنيه\n"
            f"───────────────\n"
            f"\U0001f4b0 صافي الربح: {float(total) - float(expenses):,.0f} جنيه"
        )

    elif report_type == "cash_flow":
        week_ago = (date.today() - timedelta(days=7)).isoformat()
        income = db.execute(text("SELECT COALESCE(SUM(paid_amount), 0) FROM sales_invoices WHERE DATE(created_at) >= :start"), {"start": week_ago}).scalar() or 0
        expenses = db.execute(text("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE DATE(expense_date) >= :start"), {"start": week_ago}).scalar() or 0
        purchases = db.execute(text("SELECT COALESCE(SUM(total_amount), 0) FROM purchase_invoices WHERE DATE(created_at) >= :start"), {"start": week_ago}).scalar() or 0
        return (
            f"\U0001f4b8 تقرير التدفق النقدي\n"
            f"آخر 7 أيام ({week_ago} → {today})\n"
            f"───────────────\n"
            f"\U0001f4b5 الداخل (مبيعات): {float(income):,.0f} جنيه\n"
            f"\U0001f4c9 مصروفات: {float(expenses):,.0f} جنيه\n"
            f"\U0001f6d2 مشتريات: {float(purchases):,.0f} جنيه\n"
            f"───────────────\n"
            f"\U0001f4ca صافي التدفق: {float(income) - float(expenses) - float(purchases):,.0f} جنيه"
        )

    elif report_type == "top_products":
        rows = db.execute(text("""
            SELECT p.name, SUM(si.quantity) as qty, SUM(si.total_price) as revenue
            FROM sale_items si
            JOIN products p ON p.id = si.product_id
            JOIN sales_invoices inv ON inv.id = si.invoice_id
            WHERE DATE(inv.created_at) >= :start
            GROUP BY p.id, p.name
            ORDER BY revenue DESC
            LIMIT 10
        """), {"start": (date.today() - timedelta(days=30)).isoformat()}).fetchall()
        lines = [f"\U0001f3c6 أعلى المنتجات مبيعاً (30 يوم)\n───────────────"]
        for i, (name, qty, rev) in enumerate(rows, 1):
            lines.append(f"{i}. {name}: {int(qty)} قطعة ({float(rev):,.0f} جنيه)")
        if not rows:
            lines.append("لا توجد مبيعات")
        return "\n".join(lines)

    elif report_type == "inventory_valuation":
        row = db.execute(text("""
            SELECT COUNT(id), COALESCE(SUM(quantity * cost_price), 0), COALESCE(SUM(quantity), 0)
            FROM products WHERE quantity > 0
        """)).fetchone()
        product_count, total_value, total_qty = row if row else (0, 0, 0)
        return (
            f"\U0001f4e6 تقييم المخزون\n"
            f"───────────────\n"
            f"\U0001f4cb عدد المنتجات: {product_count}\n"
            f"\U0001f4e6 إجمالي الكمية: {int(total_qty)} قطعة\n"
            f"\U0001f4b0 قيمة المخزون: {float(total_value):,.0f} جنيه"
        )

    elif report_type == "low_stock":
        rows = db.execute(text("""
            SELECT name, quantity, min_stock
            FROM products
            WHERE quantity <= min_stock AND quantity > 0
            ORDER BY quantity ASC
            LIMIT 15
        """)).fetchall()
        lines = [f"⚠️ تنبيه المخزون المنخفض\n───────────────"]
        for name, qty, min_s in rows:
            lines.append(f"• {name}: {int(qty)} (الحد الأدنى: {int(min_s)})")
        if not rows:
            lines.append("✅ لا يوجد نقص في المخزون")
        return "\n".join(lines)

    elif report_type == "customer_balances":
        rows = db.execute(text("""
            SELECT c.name, SUM(si.total_amount - si.paid_amount) as balance
            FROM customers c
            JOIN sales_invoices si ON si.customer_id = c.id
            WHERE si.payment_status IN ('unpaid', 'partial')
            GROUP BY c.id, c.name
            HAVING SUM(si.total_amount - si.paid_amount) > 0
            ORDER BY balance DESC
            LIMIT 10
        """)).fetchall()
        total = sum(float(b) for _, b in rows)
        lines = [f"\U0001f4b3 أرصدة العملاء المستحقة\n───────────────\nالإجمالي: {total:,.0f} جنيه\n"]
        for name, balance in rows:
            lines.append(f"• {name}: {float(balance):,.0f} جنيه")
        if not rows:
            lines.append("✅ لا توجد أرصدة مستحقة")
        return "\n".join(lines)

    elif report_type == "supplier_balances":
        rows = db.execute(text("""
            SELECT s.name, SUM(pi.total_amount - pi.paid_amount) as balance
            FROM suppliers s
            JOIN purchase_invoices pi ON pi.supplier_id = s.id
            WHERE pi.payment_status IN ('unpaid', 'partial')
            GROUP BY s.id, s.name
            HAVING SUM(pi.total_amount - pi.paid_amount) > 0
            ORDER BY balance DESC
            LIMIT 10
        """)).fetchall()
        total = sum(float(b) for _, b in rows)
        lines = [f"\U0001f69a أرصدة الموردين المستحقة\n───────────────\nالإجمالي: {total:,.0f} جنيه\n"]
        for name, balance in rows:
            lines.append(f"• {name}: {float(balance):,.0f} جنيه")
        if not rows:
            lines.append("✅ لا توجد مستحقات للموردين")
        return "\n".join(lines)

    elif report_type == "expense_by_category":
        first_of_month = date.today().replace(day=1).isoformat()
        rows = db.execute(text("""
            SELECT category, SUM(amount) as total
            FROM expenses
            WHERE DATE(expense_date) >= :start
            GROUP BY category
            ORDER BY total DESC
        """), {"start": first_of_month}).fetchall()
        grand_total = sum(float(t) for _, t in rows)
        lines = [f"\U0001f4c9 المصروفات حسب الفئة (هذا الشهر)\n───────────────\nالإجمالي: {grand_total:,.0f} جنيه\n"]
        for cat, total in rows:
            lines.append(f"• {cat or 'بدون فئة'}: {float(total):,.0f} جنيه")
        if not rows:
            lines.append("لا توجد مصروفات هذا الشهر")
        return "\n".join(lines)

    elif report_type == "profit_loss":
        first_of_month = date.today().replace(day=1).isoformat()
        revenue = db.execute(text("SELECT COALESCE(SUM(total_amount), 0) FROM sales_invoices WHERE DATE(created_at) >= :start"), {"start": first_of_month}).scalar() or 0
        cogs = db.execute(text("""
            SELECT COALESCE(SUM(si.quantity * p.cost_price), 0)
            FROM sale_items si
            JOIN products p ON p.id = si.product_id
            JOIN sales_invoices inv ON inv.id = si.invoice_id
            WHERE DATE(inv.created_at) >= :start
        """), {"start": first_of_month}).scalar() or 0
        expenses = db.execute(text("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE DATE(expense_date) >= :start"), {"start": first_of_month}).scalar() or 0
        gross = float(revenue) - float(cogs)
        net = gross - float(expenses)
        return (
            f"\U0001f4ca تقرير الأرباح والخسائر (هذا الشهر)\n"
            f"───────────────\n"
            f"\U0001f4b0 الإيرادات: {float(revenue):,.0f} جنيه\n"
            f"\U0001f4e6 تكلفة البضاعة: {float(cogs):,.0f} جنيه\n"
            f"\U0001f4c8 مجمل الربح: {gross:,.0f} جنيه\n"
            f"\U0001f4c9 المصروفات: {float(expenses):,.0f} جنيه\n"
            f"───────────────\n"
            f"{'✅' if net >= 0 else '❌'} صافي الربح: {net:,.0f} جنيه"
        )

    elif report_type == "stock_movement":
        week_ago = (date.today() - timedelta(days=7)).isoformat()
        sold = db.execute(text("SELECT COALESCE(SUM(quantity), 0) FROM sale_items si JOIN sales_invoices inv ON inv.id = si.invoice_id WHERE DATE(inv.created_at) >= :start"), {"start": week_ago}).scalar() or 0
        purchased = db.execute(text("SELECT COALESCE(SUM(quantity), 0) FROM purchase_items pi JOIN purchase_invoices inv ON inv.id = pi.invoice_id WHERE DATE(inv.created_at) >= :start"), {"start": week_ago}).scalar() or 0
        return (
            f"\U0001f504 حركة المخزون (آخر 7 أيام)\n"
            f"───────────────\n"
            f"\U0001f4e4 وارد (مشتريات): {int(purchased)} قطعة\n"
            f"\U0001f4e5 صادر (مبيعات): {int(sold)} قطعة\n"
            f"───────────────\n"
            f"\U0001f4ca صافي الحركة: {int(purchased) - int(sold):+d} قطعة"
        )

    elif report_type == "dead_stock":
        cutoff = (date.today() - timedelta(days=30)).isoformat()
        rows = db.execute(text("""
            SELECT p.name, p.quantity, p.cost_price * p.quantity as value
            FROM products p
            WHERE p.quantity > 0
              AND p.id NOT IN (
                  SELECT DISTINCT si.product_id FROM sale_items si
                  JOIN sales_invoices inv ON inv.id = si.invoice_id
                  WHERE DATE(inv.created_at) >= :cutoff
              )
            ORDER BY (p.cost_price * p.quantity) DESC
            LIMIT 10
        """), {"cutoff": cutoff}).fetchall()
        total_value = sum(float(v) for _, _, v in rows)
        lines = [f"\U0001f6ab مخزون راكد (لم يُباع منذ 30 يوم)\n───────────────\nقيمة الراكد: {total_value:,.0f} جنيه\n"]
        for name, qty, val in rows:
            lines.append(f"• {name}: {int(qty)} قطعة ({float(val):,.0f} جنيه)")
        if not rows:
            lines.append("✅ لا يوجد مخزون راكد")
        return "\n".join(lines)

    return None


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
