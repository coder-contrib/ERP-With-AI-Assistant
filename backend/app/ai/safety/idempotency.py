"""Idempotency layer to prevent duplicate transactions.

Prevents the same voice command from creating duplicate invoices/payments
when sent multiple times (network retry, double-tap, echo, etc.).

Strategy:
- Hash the intent (tool_name + key parameters) into a request_id
- Store in Redis with short TTL
- If request_id already exists, return the cached result instead of re-executing
"""
import json
import hashlib
from typing import Optional
from app.core.redis import get_redis
import logging

logger = logging.getLogger(__name__)

IDEMPOTENCY_KEY_PREFIX = "ai:idempotent:"
DEFAULT_TTL = 300  # 5 minutes

# Only these tools get idempotency protection
IDEMPOTENT_OPERATIONS = {
    "create_invoice",
    "record_payment",
    "refund_payment",
    "update_stock",
    "transfer_stock",
    "create_customer",
}

# Key parameters that define "same intent" per operation
INTENT_KEYS = {
    "create_invoice": ["customer_id", "items", "payment_type"],
    "record_payment": ["customer_id", "invoice_id", "amount"],
    "refund_payment": ["invoice_id", "amount"],
    "update_stock": ["product_id", "warehouse_id", "quantity"],
    "transfer_stock": ["product_id", "from_warehouse_id", "to_warehouse_id", "quantity"],
    "create_customer": ["name", "phone"],
}


def compute_request_id(session_id: str, tool_name: str, params: dict) -> str:
    """Compute a deterministic request ID from the intent."""
    keys = INTENT_KEYS.get(tool_name, [])
    intent_data = {k: params.get(k) for k in keys if k in params}
    raw = f"{session_id}:{tool_name}:{json.dumps(intent_data, sort_keys=True, default=str)}"
    return hashlib.sha256(raw.encode()).hexdigest()[:20]


class IdempotencyGuard:
    """Prevents duplicate execution of write operations."""

    def __init__(self, session_id: str):
        self.session_id = session_id
        self.redis = get_redis()

    def is_protected(self, tool_name: str) -> bool:
        """Check if this tool has idempotency protection."""
        return tool_name in IDEMPOTENT_OPERATIONS

    def check_duplicate(self, tool_name: str, params: dict) -> Optional[dict]:
        """Check if this exact operation was already executed recently.
        Returns cached result if duplicate, None if new.
        """
        if not self.is_protected(tool_name):
            return None

        request_id = compute_request_id(self.session_id, tool_name, params)
        key = f"{IDEMPOTENCY_KEY_PREFIX}{request_id}"
        cached = self.redis.get(key)

        if cached:
            logger.info(f"Idempotency hit: {tool_name} request_id={request_id}")
            result = json.loads(cached)
            result["_idempotent"] = True
            result["_message"] = "تم تنفيذ هذه العملية مسبقاً (نتيجة محفوظة)"
            return result

        return None

    def record_execution(self, tool_name: str, params: dict, result: dict, ttl: int = DEFAULT_TTL):
        """Record a successful execution for idempotency."""
        if not self.is_protected(tool_name):
            return

        request_id = compute_request_id(self.session_id, tool_name, params)
        key = f"{IDEMPOTENCY_KEY_PREFIX}{request_id}"

        self.redis.set(key, json.dumps(result, default=str), ex=ttl)
        logger.info(f"Idempotency recorded: {tool_name} request_id={request_id} ttl={ttl}s")

    def invalidate(self, tool_name: str, params: dict):
        """Manually invalidate an idempotency record (e.g., after rollback)."""
        request_id = compute_request_id(self.session_id, tool_name, params)
        key = f"{IDEMPOTENCY_KEY_PREFIX}{request_id}"
        self.redis.delete(key)
