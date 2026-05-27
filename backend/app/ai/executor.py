import json
from sqlalchemy.orm import Session
import logging

logger = logging.getLogger(__name__)


class ToolExecutor:
    """Pure execution layer. No LLM. No reasoning.
    Maps tool names to backend service functions and runs them.
    """

    def __init__(self, db: Session):
        self.db = db
        self._tools = None

    @property
    def tools(self):
        if self._tools is None:
            self._tools = self._build_tool_map()
        return self._tools

    def _build_tool_map(self) -> dict:
        from app.ai.tools.sales_tools import SalesTools
        from app.ai.tools.stock_tools import StockTools
        from app.ai.tools.finance_tools import FinanceTools
        from app.ai.tools.reporting_tools import ReportingTools
        from app.ai.tools.action_tools import ActionTools
        from app.ai.rag.retriever import ERPContextRetriever

        sales = SalesTools(self.db)
        stock = StockTools(self.db)
        finance = FinanceTools(self.db)
        reporting = ReportingTools(self.db)
        actions = ActionTools(self.db)
        retriever = ERPContextRetriever(self.db)

        return {
            # --- Read: Sales ---
            "get_today_sales": lambda **_: sales.get_today_sales(),
            "get_customer_info": lambda **p: sales.get_customer_info(p["customer_id"]),
            "get_customer_history": lambda **p: sales.get_customer_history(p["customer_id"], p.get("limit", 10)),
            "get_top_selling_products": lambda **p: sales.get_top_selling_products(p.get("limit", 10), p.get("by", "revenue")),
            "get_unpaid_invoices": lambda **p: sales.get_unpaid_invoices(p.get("customer_id")),
            # --- Read: Inventory ---
            "get_stock_level": lambda **p: stock.get_stock_level(p["product_id"], p.get("warehouse_id")),
            "get_low_stock_items": lambda **p: stock.get_low_stock_items(p.get("threshold", 10)),
            "get_stock_movement_history": lambda **p: stock.get_stock_movement_history(p["product_id"], p.get("limit", 20)),
            "get_warehouse_summary": lambda **p: stock.get_warehouse_summary(p["warehouse_id"]),
            "get_dead_stock": lambda **p: stock.get_dead_stock(p.get("days", 30)),
            "get_stock_valuation": lambda **p: stock.get_stock_valuation(p.get("warehouse_id")),
            # --- Read: Finance ---
            "get_profit_and_loss": lambda **p: finance.get_profit_and_loss(p["start_date"], p["end_date"]),
            "get_cash_balance": lambda **_: finance.get_cash_balance(),
            "get_receivables_summary": lambda **_: finance.get_receivables_summary(),
            "get_payables_summary": lambda **_: finance.get_payables_summary(),
            "get_expense_breakdown": lambda **p: finance.get_expense_breakdown(p["start_date"], p["end_date"]),
            "get_daily_revenue": lambda **p: finance.get_daily_revenue(p["start_date"], p["end_date"]),
            "demand_forecast": lambda **p: reporting.demand_forecast(p["product_id"], p.get("days_back", 30)),
            # --- Read: Search ---
            "search_products": lambda **p: retriever.search_products(p["query"]),
            "search_customers": lambda **p: retriever.search_customers(p["query"]),
            # --- Write: Sales ---
            "create_invoice": lambda **p: actions.create_invoice(
                customer_id=p.get("customer_id"),
                items=p["items"],
                payment_type=p.get("payment_type", "cash"),
                warehouse_id=p.get("warehouse_id", 1),
                discount=p.get("discount", 0),
                paid_amount=p.get("paid_amount"),
                notes=p.get("notes"),
            ),
            "cancel_invoice": lambda **p: actions.cancel_invoice(p["invoice_id"], p.get("reason")),
            "apply_discount": lambda **p: actions.apply_discount(p["invoice_id"], p["discount_amount"]),
            # --- Write: Payments ---
            "record_payment": lambda **p: actions.record_payment(
                customer_id=p["customer_id"],
                invoice_id=p["invoice_id"],
                amount=p["amount"],
                notes=p.get("notes"),
            ),
            "refund_payment": lambda **p: actions.refund_payment(p["invoice_id"], p["amount"], p.get("reason")),
            # --- Write: Inventory ---
            "update_stock": lambda **p: actions.update_stock(
                product_id=p["product_id"],
                warehouse_id=p["warehouse_id"],
                quantity=p["quantity"],
                cost_per_unit=p.get("cost_per_unit", 0),
                notes=p.get("notes"),
            ),
            "transfer_stock": lambda **p: actions.transfer_stock(
                product_id=p["product_id"],
                from_warehouse_id=p["from_warehouse_id"],
                to_warehouse_id=p["to_warehouse_id"],
                quantity=p["quantity"],
                notes=p.get("notes"),
            ),
            "adjust_stock": lambda **p: actions.adjust_stock(
                product_id=p["product_id"],
                warehouse_id=p["warehouse_id"],
                new_quantity=p["new_quantity"],
                reason=p.get("reason", "manual_adjustment"),
            ),
            # --- Write: CRM ---
            "create_customer": lambda **p: actions.create_customer(
                name=p["name"],
                phone=p.get("phone"),
                address=p.get("address"),
                credit_limit=p.get("credit_limit", 0),
                payment_terms=p.get("payment_terms", 0),
                notes=p.get("notes"),
            ),
            "update_customer": lambda **p: actions.update_customer(
                customer_id=p["customer_id"],
                name=p.get("name"),
                phone=p.get("phone"),
                address=p.get("address"),
                credit_limit=p.get("credit_limit"),
                payment_terms=p.get("payment_terms"),
                notes=p.get("notes"),
            ),
        }

    def execute(self, tool_name: str, tool_input: dict) -> str:
        """Execute a tool by name. Returns JSON string result."""
        fn = self.tools.get(tool_name)
        if not fn:
            return json.dumps({"error": f"Unknown tool: {tool_name}"})
        try:
            result = fn(**tool_input)
            return json.dumps(result, default=str)
        except Exception as e:
            logger.error(f"Tool execution error [{tool_name}]: {e}")
            return json.dumps({"error": str(e)})
