"""Transaction Safety Layer."""
import json
import hashlib
from datetime import datetime
from typing import Optional
from app.config import settings
from app.core.redis import get_redis
import logging

logger = logging.getLogger(__name__)

SENSITIVE_OPERATIONS = {
    "create_invoice",
    "cancel_invoice",
    "record_payment",
    "refund_payment",
    "adjust_stock",
    "transfer_stock",
    "update_stock",
    "set_customer_opening_balance",
    "set_supplier_opening_balance",
    "set_cash_opening_balance",
    "set_opening_inventory",
    "create_expense",
    "create_sales_return",
    "create_purchase_invoice",
    "create_purchase_return",
    "create_supplier",
    "create_product",
    # Admin sensitive operations
    "create_category",
    "delete_category",
    "create_user",
    "deactivate_user",
    "activate_user",
    "reset_user_password",
    "refresh_daily_summary",
    "refresh_summary_range",
    # WhatsApp sensitive operations
    "send_overdue_reminders",
    # Workflow sensitive operations
    "create_invoice_and_notify",
}

CONFIRMATION_THRESHOLDS = {
    "create_invoice": lambda params: _total_amount(params) > 5000,
    "record_payment": lambda params: params.get("amount", 0) > 10000,
    "refund_payment": lambda params: params.get("amount", 0) > 1000,
    "transfer_stock": lambda params: params.get("quantity", 0) > 100,
    "adjust_stock": lambda params: True,
    "set_customer_opening_balance": lambda params: params.get("amount", 0) > 10000,
    "set_supplier_opening_balance": lambda params: params.get("amount", 0) > 10000,
    "set_cash_opening_balance": lambda params: params.get("amount", 0) > 50000,
    "set_opening_inventory": lambda params: params.get("quantity", 0) * params.get("cost_per_unit", 0) > 20000,
    "create_expense": lambda params: params.get("amount", 0) > 5000,
    "create_purchase_invoice": lambda params: sum(i.get("quantity", 0) * i.get("purchase_price", 0) for i in params.get("items", [])) > 10000,
    "create_sales_return": lambda params: True,
    "create_purchase_return": lambda params: True,
    # Admin thresholds
    "create_user": lambda params: True,
    "deactivate_user": lambda params: True,
    "activate_user": lambda params: True,
    "reset_user_password": lambda params: True,
    "delete_category": lambda params: True,
    "refresh_daily_summary": lambda params: False,
    "refresh_summary_range": lambda params: False,
    # WhatsApp thresholds (bulk messages always require confirmation)
    "send_overdue_reminders": lambda params: True,
    # Workflow thresholds (invoice+notify uses same threshold as invoice)
    "create_invoice_and_notify": lambda params: _total_amount(params) > 5000,
}

PENDING_KEY_PREFIX = "ai:pending_tx:"
ROLLBACK_KEY_PREFIX = "ai:rollback:"


def _total_amount(params: dict) -> float:
    items = params.get("items", [])
    total = sum(item.get("quantity", 0) * item.get("unit_price", 0) for item in items)
    return total - params.get("discount", 0)


class TransactionGuard:
    def __init__(self):
        self.redis = get_redis()

    def needs_confirmation(self, tool_name: str, params: dict) -> bool:
        if tool_name not in SENSITIVE_OPERATIONS:
            return False
        threshold_fn = CONFIRMATION_THRESHOLDS.get(tool_name)
        if threshold_fn:
            return threshold_fn(params)
        return True

    def dry_run(self, tool_name: str, params: dict) -> dict:
        preview = {
            "operation": tool_name,
            "status": "preview",
            "would_do": self._describe_operation(tool_name, params),
            "params": params,
            "requires_confirmation": self.needs_confirmation(tool_name, params),
        }

        if tool_name == "create_invoice":
            preview["estimated_total"] = _total_amount(params)
            preview["payment_type"] = params.get("payment_type", "cash")
            preview["item_count"] = len(params.get("items", []))
        elif tool_name == "create_invoice_and_notify":
            preview["estimated_total"] = _total_amount(params)
            preview["payment_type"] = params.get("payment_type", "cash")
            preview["item_count"] = len(params.get("items", []))
            preview["will_send_whatsapp"] = True
        elif tool_name == "record_payment":
            preview["amount"] = params.get("amount", 0)
        elif tool_name == "refund_payment":
            preview["refund_amount"] = params.get("amount", 0)
        elif tool_name in ("transfer_stock", "update_stock", "adjust_stock"):
            preview["quantity"] = params.get("quantity", params.get("new_quantity", 0))
        elif tool_name == "create_expense":
            preview["amount"] = params.get("amount", 0)
            preview["category"] = params.get("category", "Miscellaneous")
        elif tool_name == "create_purchase_invoice":
            preview["item_count"] = len(params.get("items", []))
            preview["estimated_total"] = sum(i.get("quantity", 0) * i.get("purchase_price", 0) for i in params.get("items", []))
        elif tool_name in ("set_customer_opening_balance", "set_supplier_opening_balance", "set_cash_opening_balance"):
            preview["amount"] = params.get("amount", 0)
        elif tool_name == "set_opening_inventory":
            preview["quantity"] = params.get("quantity", 0)
            preview["total_value"] = params.get("quantity", 0) * params.get("cost_per_unit", 0)
        elif tool_name == "create_user":
            preview["username"] = params.get("username", "")
            preview["role"] = params.get("role", "")
        elif tool_name in ("deactivate_user", "activate_user", "reset_user_password"):
            preview["user_id"] = params.get("user_id", 0)
        elif tool_name == "delete_category":
            preview["category_id"] = params.get("category_id", 0)
        elif tool_name == "send_overdue_reminders":
            preview["action"] = "bulk WhatsApp reminders to overdue customers"

        return preview

    def store_pending(self, session_id: str, tool_name: str, params: dict) -> str:
        confirmation_id = hashlib.sha256(
            f"{session_id}:{tool_name}:{json.dumps(params, sort_keys=True)}:{datetime.utcnow().isoformat()}".encode()
        ).hexdigest()[:12]
        self.redis.set(
            f"{PENDING_KEY_PREFIX}{confirmation_id}",
            json.dumps({"session_id": session_id, "tool_name": tool_name, "params": params, "created_at": datetime.utcnow().isoformat(), "preview": self.dry_run(tool_name, params)}, default=str),
            ex=300,
        )
        return confirmation_id

    def get_pending(self, confirmation_id: str) -> Optional[dict]:
        raw = self.redis.get(f"{PENDING_KEY_PREFIX}{confirmation_id}")
        return json.loads(raw) if raw else None

    def confirm_and_clear(self, confirmation_id: str) -> Optional[dict]:
        raw = self.redis.get(f"{PENDING_KEY_PREFIX}{confirmation_id}")
        if not raw:
            return None
        self.redis.delete(f"{PENDING_KEY_PREFIX}{confirmation_id}")
        return json.loads(raw)

    def store_rollback_info(self, tool_name: str, params: dict, result: dict) -> str:
        rollback_id = hashlib.sha256(
            f"{tool_name}:{json.dumps(result, sort_keys=True, default=str)}".encode()
        ).hexdigest()[:12]
        rollback_data = {
            "rollback_id": rollback_id, "original_operation": tool_name,
            "original_params": params, "result": result,
            "created_at": datetime.utcnow().isoformat(),
            "reverse_action": self._get_reverse_action(tool_name, params, result),
        }
        self.redis.set(f"{ROLLBACK_KEY_PREFIX}{rollback_id}", json.dumps(rollback_data, default=str), ex=60 * 60 * 24)
        return rollback_id

    def get_rollback_info(self, rollback_id: str) -> Optional[dict]:
        raw = self.redis.get(f"{ROLLBACK_KEY_PREFIX}{rollback_id}")
        return json.loads(raw) if raw else None

    def _describe_operation(self, tool_name: str, params: dict) -> str:
        descriptions = {
            "create_invoice": lambda p: f"إنشاء فاتورة بـ {len(p.get('items', []))} أصناف، إجمالي تقريبي: {_total_amount(p)} جنيه",
            "create_invoice_and_notify": lambda p: f"إنشاء فاتورة بـ {len(p.get('items', []))} أصناف (إجمالي: {_total_amount(p)} جنيه) + إرسال إشعار واتساب للعميل",
            "cancel_invoice": lambda p: f"إلغاء الفاتورة رقم {p.get('invoice_id')}",
            "record_payment": lambda p: f"تسجيل دفعة {p.get('amount')} جنيه للعميل {p.get('customer_id')}",
            "refund_payment": lambda p: f"رد مبلغ {p.get('amount')} جنيه من فاتورة {p.get('invoice_id')}",
            "update_stock": lambda p: f"تحديث مخزون منتج {p.get('product_id')}: +{p.get('quantity')} وحدة",
            "transfer_stock": lambda p: f"نقل {p.get('quantity')} وحدة من منتج {p.get('product_id')} من مخزن {p.get('from_warehouse_id')} إلى {p.get('to_warehouse_id')}",
            "adjust_stock": lambda p: f"تعديل مخزون منتج {p.get('product_id')} إلى {p.get('new_quantity')} وحدة",
            "create_customer": lambda p: f"إنشاء عميل جديد: {p.get('name')}",
            "update_customer": lambda p: f"تعديل بيانات العميل {p.get('customer_id')}",
            "set_customer_opening_balance": lambda p: f"تسجيل رصيد أول المدة {p.get('amount')} جنيه للعميل #{p.get('customer_id')}",
            "set_supplier_opening_balance": lambda p: f"تسجيل رصيد أول المدة {p.get('amount')} جنيه للمورد #{p.get('supplier_id')}",
            "set_cash_opening_balance": lambda p: f"تسجيل رصيد الصندوق أول المدة {p.get('amount')} جنيه",
            "set_opening_inventory": lambda p: f"تسجيل مخزون أول المدة: {p.get('quantity')} وحدة من المنتج #{p.get('product_id')}",
            "create_expense": lambda p: f"تسجيل مصروف '{p.get('name')}' بمبلغ {p.get('amount')} جنيه",
            "create_sales_return": lambda p: f"مرتجع مبيعات من الفاتورة #{p.get('invoice_id')} ({len(p.get('items', []))} أصناف)",
            "create_purchase_invoice": lambda p: f"فاتورة مشتريات بـ {len(p.get('items', []))} أصناف للمورد #{p.get('supplier_id')}",
            "create_purchase_return": lambda p: f"مرتجع مشتريات من الفاتورة #{p.get('purchase_invoice_id')} ({len(p.get('items', []))} أصناف)",
            "create_supplier": lambda p: f"إنشاء مورد جديد: {p.get('name')}",
            "update_supplier": lambda p: f"تعديل بيانات المورد #{p.get('supplier_id')}",
            "create_product": lambda p: f"إنشاء منتج جديد: {p.get('name')}",
            "update_product": lambda p: f"تعديل بيانات المنتج #{p.get('product_id')}",
            # Admin descriptions
            "create_category": lambda p: f"إنشاء تصنيف جديد: {p.get('name')}",
            "delete_category": lambda p: f"حذف التصنيف #{p.get('category_id')}",
            "create_user": lambda p: f"إنشاء مستخدم جديد: {p.get('username')} (صلاحية: {p.get('role')})",
            "deactivate_user": lambda p: f"تعطيل حساب المستخدم #{p.get('user_id')}",
            "activate_user": lambda p: f"تفعيل حساب المستخدم #{p.get('user_id')}",
            "reset_user_password": lambda p: f"إعادة تعيين كلمة مرور المستخدم #{p.get('user_id')}",
            "refresh_daily_summary": lambda p: f"تحديث الملخص المالي ليوم {p.get('target_date', 'اليوم')}",
            "refresh_summary_range": lambda p: f"تحديث الملخص المالي من {p.get('start_date')} إلى {p.get('end_date', 'اليوم')}",
            # WhatsApp descriptions
            "send_overdue_reminders": lambda p: "إرسال تذكيرات جماعية عبر واتساب للعملاء المتأخرين في السداد",
        }
        fn = descriptions.get(tool_name)
        return fn(params) if fn else f"تنفيذ {tool_name}"

    def _get_reverse_action(self, tool_name: str, params: dict, result: dict) -> Optional[dict]:
        if tool_name in ("create_invoice", "create_invoice_and_notify"):
            invoice_id = result.get("invoice_id") or result.get("id")
            if invoice_id:
                return {"tool": "cancel_invoice", "params": {"invoice_id": invoice_id, "reason": "rollback"}}
        elif tool_name == "record_payment":
            return {"tool": "refund_payment", "params": {"invoice_id": params.get("invoice_id"), "amount": params.get("amount"), "reason": "rollback"}}
        elif tool_name == "transfer_stock":
            return {"tool": "transfer_stock", "params": {"product_id": params.get("product_id"), "from_warehouse_id": params.get("to_warehouse_id"), "to_warehouse_id": params.get("from_warehouse_id"), "quantity": params.get("quantity"), "notes": "rollback"}}
        elif tool_name == "create_purchase_invoice":
            pid = result.get("purchase_invoice_id")
            if pid:
                return {"tool": "create_purchase_return", "params": {"purchase_invoice_id": pid, "items": params.get("items", []), "reason": "rollback"}}
        return None
