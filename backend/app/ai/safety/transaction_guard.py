"""Transaction Safety Layer.

Provides:
1. Dry-run mode: preview what a write operation WOULD do before executing
2. Confirmation step: sensitive operations require explicit confirmation
3. Rollback registry: stores info needed to reverse completed transactions
"""
import json
import hashlib
from datetime import datetime
from typing import Optional
from app.config import settings
from app.core.redis import get_redis
import logging

logger = logging.getLogger(__name__)

# Operations that require confirmation before execution
SENSITIVE_OPERATIONS = {
    "create_invoice",
    "cancel_invoice",
    "record_payment",
    "refund_payment",
    "adjust_stock",
    "transfer_stock",
    "update_stock",
}

# Thresholds that trigger mandatory confirmation
CONFIRMATION_THRESHOLDS = {
    "create_invoice": lambda params: _total_amount(params) > 5000,
    "record_payment": lambda params: params.get("amount", 0) > 10000,
    "refund_payment": lambda params: params.get("amount", 0) > 1000,
    "transfer_stock": lambda params: params.get("quantity", 0) > 100,
    "adjust_stock": lambda params: True,  # always confirm stock adjustments
}

PENDING_KEY_PREFIX = "ai:pending_tx:"
ROLLBACK_KEY_PREFIX = "ai:rollback:"


def _total_amount(params: dict) -> float:
    items = params.get("items", [])
    total = 0
    for item in items:
        total += item.get("quantity", 0) * item.get("unit_price", 0)
    discount = params.get("discount", 0)
    return total - discount


class TransactionGuard:
    """Guards write operations with dry-run preview and confirmation."""

    def __init__(self):
        self.redis = get_redis()

    def needs_confirmation(self, tool_name: str, params: dict) -> bool:
        """Check if this operation requires user confirmation."""
        if tool_name not in SENSITIVE_OPERATIONS:
            return False
        threshold_fn = CONFIRMATION_THRESHOLDS.get(tool_name)
        if threshold_fn:
            return threshold_fn(params)
        return True

    def dry_run(self, tool_name: str, params: dict) -> dict:
        """Preview what this operation WOULD do without executing.
        Returns a human-readable summary.
        """
        preview = {
            "operation": tool_name,
            "status": "preview",
            "would_do": self._describe_operation(tool_name, params),
            "params": params,
            "requires_confirmation": self.needs_confirmation(tool_name, params),
        }

        if tool_name == "create_invoice":
            total = _total_amount(params)
            preview["estimated_total"] = total
            preview["payment_type"] = params.get("payment_type", "cash")
            preview["item_count"] = len(params.get("items", []))

        elif tool_name == "record_payment":
            preview["amount"] = params.get("amount", 0)

        elif tool_name == "refund_payment":
            preview["refund_amount"] = params.get("amount", 0)

        elif tool_name in ("transfer_stock", "update_stock", "adjust_stock"):
            preview["quantity"] = params.get("quantity", params.get("new_quantity", 0))

        return preview

    def store_pending(self, session_id: str, tool_name: str, params: dict) -> str:
        """Store a pending transaction awaiting confirmation.
        Returns a confirmation_id the user must send back.
        """
        confirmation_id = hashlib.sha256(
            f"{session_id}:{tool_name}:{json.dumps(params, sort_keys=True)}:{datetime.utcnow().isoformat()}".encode()
        ).hexdigest()[:12]

        self.redis.set(
            f"{PENDING_KEY_PREFIX}{confirmation_id}",
            json.dumps({
                "session_id": session_id,
                "tool_name": tool_name,
                "params": params,
                "created_at": datetime.utcnow().isoformat(),
                "preview": self.dry_run(tool_name, params),
            }, default=str),
            ex=300,  # 5 min expiry
        )
        return confirmation_id

    def get_pending(self, confirmation_id: str) -> Optional[dict]:
        """Retrieve a pending transaction by confirmation ID."""
        raw = self.redis.get(f"{PENDING_KEY_PREFIX}{confirmation_id}")
        if not raw:
            return None
        return json.loads(raw)

    def confirm_and_clear(self, confirmation_id: str) -> Optional[dict]:
        """Confirm a pending transaction. Returns the stored tx data, deletes pending."""
        raw = self.redis.get(f"{PENDING_KEY_PREFIX}{confirmation_id}")
        if not raw:
            return None
        self.redis.delete(f"{PENDING_KEY_PREFIX}{confirmation_id}")
        return json.loads(raw)

    def store_rollback_info(self, tool_name: str, params: dict, result: dict) -> str:
        """Store rollback information after a successful write operation.
        Returns a rollback_id.
        """
        rollback_id = hashlib.sha256(
            f"{tool_name}:{json.dumps(result, sort_keys=True, default=str)}".encode()
        ).hexdigest()[:12]

        rollback_data = {
            "rollback_id": rollback_id,
            "original_operation": tool_name,
            "original_params": params,
            "result": result,
            "created_at": datetime.utcnow().isoformat(),
            "reverse_action": self._get_reverse_action(tool_name, params, result),
        }

        self.redis.set(
            f"{ROLLBACK_KEY_PREFIX}{rollback_id}",
            json.dumps(rollback_data, default=str),
            ex=60 * 60 * 24,  # 24 hour TTL
        )
        return rollback_id

    def get_rollback_info(self, rollback_id: str) -> Optional[dict]:
        """Get rollback info for a completed transaction."""
        raw = self.redis.get(f"{ROLLBACK_KEY_PREFIX}{rollback_id}")
        if not raw:
            return None
        return json.loads(raw)

    def _describe_operation(self, tool_name: str, params: dict) -> str:
        descriptions = {
            "create_invoice": lambda p: f"إنشاء فاتورة بـ {len(p.get('items', []))} أصناف، إجمالي تقريبي: {_total_amount(p)} جنيه",
            "cancel_invoice": lambda p: f"إلغاء الفاتورة رقم {p.get('invoice_id')}",
            "record_payment": lambda p: f"تسجيل دفعة {p.get('amount')} جنيه للعميل {p.get('customer_id')}",
            "refund_payment": lambda p: f"رد مبلغ {p.get('amount')} جنيه من فاتورة {p.get('invoice_id')}",
            "update_stock": lambda p: f"تحديث مخزون منتج {p.get('product_id')}: +{p.get('quantity')} وحدة",
            "transfer_stock": lambda p: f"نقل {p.get('quantity')} وحدة من منتج {p.get('product_id')} من مخزن {p.get('from_warehouse_id')} إلى {p.get('to_warehouse_id')}",
            "adjust_stock": lambda p: f"تعديل مخزون منتج {p.get('product_id')} إلى {p.get('new_quantity')} وحدة",
            "create_customer": lambda p: f"إنشاء عميل جديد: {p.get('name')}",
            "update_customer": lambda p: f"تعديل بيانات العميل {p.get('customer_id')}",
        }
        fn = descriptions.get(tool_name)
        return fn(params) if fn else f"تنفيذ {tool_name}"

    def _get_reverse_action(self, tool_name: str, params: dict, result: dict) -> Optional[dict]:
        """Determine the reverse action for rollback."""
        if tool_name == "create_invoice":
            invoice_id = result.get("invoice_id") or result.get("id")
            if invoice_id:
                return {"tool": "cancel_invoice", "params": {"invoice_id": invoice_id, "reason": "rollback"}}

        elif tool_name == "record_payment":
            return {"tool": "refund_payment", "params": {
                "invoice_id": params.get("invoice_id"),
                "amount": params.get("amount"),
                "reason": "rollback",
            }}

        elif tool_name == "transfer_stock":
            return {"tool": "transfer_stock", "params": {
                "product_id": params.get("product_id"),
                "from_warehouse_id": params.get("to_warehouse_id"),
                "to_warehouse_id": params.get("from_warehouse_id"),
                "quantity": params.get("quantity"),
                "notes": "rollback",
            }}

        return None
