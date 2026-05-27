"""AI Permission Hierarchy."""
from typing import Optional
import logging

logger = logging.getLogger(__name__)


class AIPermissionDenied(Exception):
    def __init__(self, tool_name: str, role: str, reason: str):
        self.tool_name = tool_name
        self.role = role
        self.reason = reason
        super().__init__(f"Permission denied: {tool_name} for role {role} - {reason}")


ROLE_AI_TOOLS = {
    "admin": "*",
    "manager": {
        "allowed": [
            "get_today_sales", "get_customer_info", "get_customer_history",
            "get_top_selling_products", "get_unpaid_invoices",
            "get_stock_level", "get_low_stock_items", "get_stock_movement_history",
            "get_warehouse_summary", "get_dead_stock", "get_stock_valuation",
            "get_profit_and_loss", "get_cash_balance", "get_receivables_summary",
            "get_payables_summary", "get_expense_breakdown", "get_daily_revenue",
            "demand_forecast", "search_products", "search_customers",
            "get_opening_balances", "list_expenses", "get_expense_summary",
            "list_sales_invoices", "get_sales_invoice", "get_invoice_items",
            "list_purchase_invoices", "get_purchase_invoice", "get_purchase_items",
            "search_suppliers", "get_product",
            "create_invoice", "cancel_invoice", "apply_discount",
            "record_payment", "refund_payment",
            "update_stock", "transfer_stock", "adjust_stock",
            "create_customer", "update_customer",
            "set_customer_opening_balance", "set_supplier_opening_balance",
            "set_cash_opening_balance", "set_opening_inventory",
            "create_expense", "create_sales_return",
            "create_purchase_invoice", "create_purchase_return",
            "create_supplier", "update_supplier",
            "create_product", "update_product",
            # Admin tools (manager has access to most)
            "list_categories", "create_category", "update_category", "delete_category",
            "get_monthly_profit", "get_cash_flow", "get_waste_report",
            "get_notifications", "mark_notification_read", "mark_all_notifications_read",
            "check_low_stock_alerts", "check_credit_limit_alerts", "check_overdue_supplier_alerts",
            "scan_anomalies", "detect_revenue_anomaly", "detect_expense_anomaly",
            "get_business_insights", "why_profit_dropped", "get_top_risks",
            "get_dashboard_summary",
            "refresh_daily_summary", "refresh_summary_range",
            "list_users",
            "get_ledger_entries", "get_account_balance", "get_trial_balance",
            "confirm_transaction",
        ],
    },
    "cashier": {
        "allowed": [
            "get_today_sales", "get_customer_info", "get_customer_history",
            "get_unpaid_invoices", "get_stock_level",
            "search_products", "search_customers",
            "list_sales_invoices", "get_sales_invoice", "get_invoice_items",
            "get_expense_summary", "get_product",
            "create_invoice", "apply_discount",
            "record_payment",
            "create_customer", "update_customer",
            "create_expense",
            # Admin tools (limited for cashier)
            "list_categories",
            "get_notifications", "mark_notification_read",
            "get_dashboard_summary",
            "confirm_transaction",
        ],
        "blocked": [
            "cancel_invoice", "refund_payment", "adjust_stock",
            "transfer_stock", "update_stock",
            "set_customer_opening_balance", "set_supplier_opening_balance",
            "set_cash_opening_balance", "set_opening_inventory",
            "create_purchase_invoice", "create_purchase_return",
            "create_supplier", "update_supplier",
            "create_product", "update_product",
            "create_category", "update_category", "delete_category",
            "scan_anomalies", "detect_revenue_anomaly", "detect_expense_anomaly",
            "get_business_insights", "why_profit_dropped",
            "refresh_daily_summary", "refresh_summary_range",
            "list_users", "create_user", "deactivate_user", "activate_user", "reset_user_password",
            "get_ledger_entries", "get_account_balance", "get_trial_balance",
        ],
    },
    "warehouse_employee": {
        "allowed": [
            "get_stock_level", "get_low_stock_items", "get_stock_movement_history",
            "get_warehouse_summary", "get_dead_stock", "get_stock_valuation",
            "search_products", "get_product",
            "list_purchase_invoices", "get_purchase_invoice", "get_purchase_items",
            "search_suppliers",
            "update_stock", "transfer_stock",
            "set_opening_inventory",
            # Admin tools (warehouse-relevant only)
            "list_categories",
            "get_notifications", "mark_notification_read",
            "check_low_stock_alerts",
            "get_waste_report",
            "get_dashboard_summary",
            "confirm_transaction",
        ],
        "blocked": [
            "create_invoice", "cancel_invoice", "record_payment",
            "refund_payment", "adjust_stock",
            "create_customer", "update_customer",
            "set_customer_opening_balance", "set_supplier_opening_balance",
            "set_cash_opening_balance", "create_expense",
            "create_purchase_invoice", "create_purchase_return",
            "create_category", "update_category", "delete_category",
            "scan_anomalies", "detect_revenue_anomaly", "detect_expense_anomaly",
            "get_business_insights", "why_profit_dropped",
            "refresh_daily_summary", "refresh_summary_range",
            "list_users", "create_user", "deactivate_user", "activate_user", "reset_user_password",
            "get_ledger_entries", "get_account_balance", "get_trial_balance",
        ],
    },
    "accountant": {
        "allowed": [
            "get_today_sales", "get_customer_info", "get_customer_history",
            "get_top_selling_products", "get_unpaid_invoices",
            "get_stock_level", "get_stock_valuation",
            "get_profit_and_loss", "get_cash_balance", "get_receivables_summary",
            "get_payables_summary", "get_expense_breakdown", "get_daily_revenue",
            "demand_forecast", "search_products", "search_customers",
            "get_opening_balances", "list_expenses", "get_expense_summary",
            "list_sales_invoices", "get_sales_invoice", "get_invoice_items",
            "list_purchase_invoices", "get_purchase_invoice", "get_purchase_items",
            "search_suppliers", "get_product",
            "record_payment",
            "set_customer_opening_balance", "set_supplier_opening_balance",
            "set_cash_opening_balance", "set_opening_inventory",
            "create_expense",
            # Admin tools (full financial access)
            "list_categories",
            "get_monthly_profit", "get_cash_flow", "get_waste_report",
            "get_notifications", "mark_notification_read", "mark_all_notifications_read",
            "check_low_stock_alerts", "check_credit_limit_alerts", "check_overdue_supplier_alerts",
            "scan_anomalies", "detect_revenue_anomaly", "detect_expense_anomaly",
            "get_business_insights", "why_profit_dropped", "get_top_risks",
            "get_dashboard_summary",
            "refresh_daily_summary", "refresh_summary_range",
            "get_ledger_entries", "get_account_balance", "get_trial_balance",
            "confirm_transaction",
        ],
        "blocked": [
            "create_invoice", "cancel_invoice", "refund_payment",
            "update_stock", "transfer_stock", "adjust_stock",
            "create_customer",
            "create_purchase_invoice", "create_purchase_return",
            "create_sales_return",
            "create_supplier", "update_supplier",
            "create_product", "update_product",
            "create_category", "update_category", "delete_category",
            "list_users", "create_user", "deactivate_user", "activate_user", "reset_user_password",
        ],
    },
    "ai_agent": {
        "allowed": [
            "get_today_sales", "get_customer_info", "get_customer_history",
            "get_top_selling_products", "get_unpaid_invoices",
            "get_stock_level", "get_low_stock_items",
            "get_cash_balance", "get_receivables_summary",
            "search_products", "search_customers",
            "get_opening_balances", "list_expenses", "get_expense_summary",
            "list_sales_invoices", "get_sales_invoice", "get_invoice_items",
            "list_purchase_invoices", "get_purchase_invoice", "get_purchase_items",
            "search_suppliers", "get_product",
            # Admin tools (read-only)
            "list_categories",
            "get_monthly_profit", "get_cash_flow", "get_waste_report",
            "get_notifications",
            "scan_anomalies", "detect_revenue_anomaly", "detect_expense_anomaly",
            "get_business_insights", "why_profit_dropped", "get_top_risks",
            "get_dashboard_summary",
            "get_ledger_entries", "get_account_balance", "get_trial_balance",
        ],
        "blocked": "*_write",
    },
}

ROLE_AMOUNT_LIMITS = {
    "admin": float("inf"),
    "manager": 100_000,
    "cashier": 20_000,
    "warehouse_employee": 0,
    "accountant": 50_000,
    "ai_agent": 5_000,
}

ROLE_CONFIRMATION_THRESHOLDS = {
    "admin": 50_000,
    "manager": 20_000,
    "cashier": 5_000,
    "warehouse_employee": 50,
    "accountant": 10_000,
    "ai_agent": 1_000,
}


class AIPermissionChecker:
    def __init__(self, user_role: str = "ai_agent"):
        self.role = user_role

    def can_execute(self, tool_name: str) -> bool:
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
        if not self.can_execute(tool_name):
            raise AIPermissionDenied(
                tool_name=tool_name, role=self.role,
                reason=f"الصلاحية '{self.role}' لا تسمح بتنفيذ '{tool_name}' عبر المساعد الذكي",
            )

    def check_amount(self, tool_name: str, amount: float) -> None:
        limit = ROLE_AMOUNT_LIMITS.get(self.role, 0)
        if amount > limit:
            raise AIPermissionDenied(
                tool_name=tool_name, role=self.role,
                reason=f"المبلغ {amount} يتجاوز الحد المسموح ({limit}) للصلاحية '{self.role}'",
            )

    def get_confirmation_threshold(self) -> float:
        return ROLE_CONFIRMATION_THRESHOLDS.get(self.role, 1000)

    def get_allowed_tools(self) -> list[str]:
        role_config = ROLE_AI_TOOLS.get(self.role)
        if role_config == "*":
            return ["*"]
        if isinstance(role_config, dict):
            return role_config.get("allowed", [])
        return []

    def get_blocked_tools(self) -> list[str]:
        role_config = ROLE_AI_TOOLS.get(self.role)
        if role_config == "*":
            return []
        if isinstance(role_config, dict):
            blocked = role_config.get("blocked", [])
            return blocked if isinstance(blocked, list) else []
        return []
