"""AI Permission Hierarchy.

Maps user roles to AI tool permissions. The AI agent inherits
the permissions of the user who is interacting with it.

Hierarchy:
  admin       → full access to all AI tools
  manager     → all read + most write (no user management via AI)
  cashier     → sales read/write + payments, limited stock access
  warehouse   → inventory read/write, no financial operations
  ai_agent    → minimal default (read-only) when no user context

The AI itself has an additional constraint layer on top of role permissions:
- Amount limits per role
- Tool blacklists per role
- Mandatory confirmation thresholds per role
"""
from typing import Optional
import logging

logger = logging.getLogger(__name__)


class AIPermissionDenied(Exception):
    """Raised when the AI attempts an operation the user's role doesn't allow."""

    def __init__(self, tool_name: str, role: str, reason: str):
        self.tool_name = tool_name
        self.role = role
        self.reason = reason
        super().__init__(f"Permission denied: {tool_name} for role {role} - {reason}")


# Which tools each role can use through the AI
ROLE_AI_TOOLS = {
    "admin": "*",  # All tools
    "manager": {
        "allowed": [
            # All read tools
            "get_today_sales", "get_customer_info", "get_customer_history",
            "get_top_selling_products", "get_unpaid_invoices",
            "get_stock_level", "get_low_stock_items", "get_stock_movement_history",
            "get_warehouse_summary", "get_dead_stock", "get_stock_valuation",
            "get_profit_and_loss", "get_cash_balance", "get_receivables_summary",
            "get_payables_summary", "get_expense_breakdown", "get_daily_revenue",
            "demand_forecast", "search_products", "search_customers",
            # Write tools
            "create_invoice", "cancel_invoice", "apply_discount",
            "record_payment", "refund_payment",
            "update_stock", "transfer_stock", "adjust_stock",
            "create_customer", "update_customer",
            "confirm_transaction",
        ],
    },
    "cashier": {
        "allowed": [
            # Read
            "get_today_sales", "get_customer_info", "get_customer_history",
            "get_unpaid_invoices", "get_stock_level",
            "search_products", "search_customers",
            # Write
            "create_invoice", "apply_discount",
            "record_payment",
            "create_customer", "update_customer",
            "confirm_transaction",
        ],
        "blocked": [
            "cancel_invoice", "refund_payment", "adjust_stock",
            "transfer_stock", "update_stock",
        ],
    },
    "warehouse_employee": {
        "allowed": [
            # Read
            "get_stock_level", "get_low_stock_items", "get_stock_movement_history",
            "get_warehouse_summary", "get_dead_stock", "get_stock_valuation",
            "search_products",
            # Write
            "update_stock", "transfer_stock",
            "confirm_transaction",
        ],
        "blocked": [
            "create_invoice", "cancel_invoice", "record_payment",
            "refund_payment", "adjust_stock",
            "create_customer", "update_customer",
        ],
    },
    "accountant": {
        "allowed": [
            # All read
            "get_today_sales", "get_customer_info", "get_customer_history",
            "get_top_selling_products", "get_unpaid_invoices",
            "get_stock_level", "get_stock_valuation",
            "get_profit_and_loss", "get_cash_balance", "get_receivables_summary",
            "get_payables_summary", "get_expense_breakdown", "get_daily_revenue",
            "demand_forecast", "search_products", "search_customers",
            # Limited write
            "record_payment",
            "confirm_transaction",
        ],
        "blocked": [
            "create_invoice", "cancel_invoice", "refund_payment",
            "update_stock", "transfer_stock", "adjust_stock",
            "create_customer",
        ],
    },
    # Default for AI when no user context is available
    "ai_agent": {
        "allowed": [
            "get_today_sales", "get_customer_info", "get_customer_history",
            "get_top_selling_products", "get_unpaid_invoices",
            "get_stock_level", "get_low_stock_items",
            "get_cash_balance", "get_receivables_summary",
            "search_products", "search_customers",
        ],
        "blocked": "*_write",
    },
}

# Amount limits per role (max single transaction)
ROLE_AMOUNT_LIMITS = {
    "admin": float("inf"),
    "manager": 100_000,
    "cashier": 20_000,
    "warehouse_employee": 0,  # No financial operations
    "accountant": 50_000,
    "ai_agent": 5_000,
}

# Confirmation thresholds per role (force confirmation above this)
ROLE_CONFIRMATION_THRESHOLDS = {
    "admin": 50_000,
    "manager": 20_000,
    "cashier": 5_000,
    "warehouse_employee": 50,  # Even small stock moves need confirmation
    "accountant": 10_000,
    "ai_agent": 1_000,
}


class AIPermissionChecker:
    """Checks if the AI can execute a tool on behalf of a user role."""

    def __init__(self, user_role: str = "ai_agent"):
        self.role = user_role

    def can_execute(self, tool_name: str) -> bool:
        """Check if the current role allows this tool."""
        role_config = ROLE_AI_TOOLS.get(self.role)
        if role_config is None:
            return False
        if role_config == "*":
            return True
        if isinstance(role_config, dict):
            allowed = role_config.get("allowed", [])
            return tool_name in allowed
        return False

    def check_or_raise(self, tool_name: str) -> None:
        """Raise AIPermissionDenied if tool is not allowed."""
        if not self.can_execute(tool_name):
            raise AIPermissionDenied(
                tool_name=tool_name,
                role=self.role,
                reason=f"الصلاحية '{self.role}' لا تسمح بتنفيذ '{tool_name}' عبر المساعد الذكي",
            )

    def check_amount(self, tool_name: str, amount: float) -> None:
        """Check if the amount is within role limits."""
        limit = ROLE_AMOUNT_LIMITS.get(self.role, 0)
        if amount > limit:
            raise AIPermissionDenied(
                tool_name=tool_name,
                role=self.role,
                reason=f"المبلغ {amount} يتجاوز الحد المسموح ({limit}) للصلاحية '{self.role}'",
            )

    def get_confirmation_threshold(self) -> float:
        """Get the amount above which confirmation is mandatory for this role."""
        return ROLE_CONFIRMATION_THRESHOLDS.get(self.role, 1000)

    def get_allowed_tools(self) -> list[str]:
        """Get list of tools this role can use."""
        role_config = ROLE_AI_TOOLS.get(self.role)
        if role_config == "*":
            return ["*"]
        if isinstance(role_config, dict):
            return role_config.get("allowed", [])
        return []

    def get_blocked_tools(self) -> list[str]:
        """Get list of tools explicitly blocked for this role."""
        role_config = ROLE_AI_TOOLS.get(self.role)
        if role_config == "*":
            return []
        if isinstance(role_config, dict):
            blocked = role_config.get("blocked", [])
            return blocked if isinstance(blocked, list) else []
        return []
