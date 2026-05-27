import anthropic
import json
from sqlalchemy.orm import Session
from app.config import settings
from app.ai.prompts.system_prompts import (
    SALES_AGENT_PROMPT,
    INVENTORY_AGENT_PROMPT,
    ACCOUNTING_AGENT_PROMPT,
)


class SubAgent:
    """A specialized sub-agent that handles a specific domain.
    Each sub-agent has its own system prompt and tools.
    Called by the Manager Agent to handle delegated tasks.
    """

    def __init__(self, db: Session, system_prompt: str, tools: list[dict], tool_executor):
        self.db = db
        self.system_prompt = system_prompt
        self.tools = tools
        self.tool_executor = tool_executor
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self.model = settings.ai_model

    def execute(self, task: str) -> str:
        messages = [{"role": "user", "content": task}]

        response = self.client.messages.create(
            model=self.model,
            max_tokens=4096,
            system=self.system_prompt,
            tools=self.tools,
            messages=messages,
        )

        while response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    result = self.tool_executor(block.name, block.input)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result,
                    })

            messages.append({"role": "assistant", "content": response.content})
            messages.append({"role": "user", "content": tool_results})

            response = self.client.messages.create(
                model=self.model,
                max_tokens=4096,
                system=self.system_prompt,
                tools=self.tools,
                messages=messages,
            )

        text = ""
        for block in response.content:
            if hasattr(block, "text"):
                text += block.text
        return text


def build_sales_agent(db: Session) -> SubAgent:
    from app.ai.tools.sales_tools import SalesTools
    from app.ai.tools.action_tools import ActionTools
    from app.ai.rag.retriever import ERPContextRetriever

    sales = SalesTools(db)
    actions = ActionTools(db)
    retriever = ERPContextRetriever(db)

    tools = [
        {"name": "get_today_sales", "description": "Get today's sales summary", "input_schema": {"type": "object", "properties": {}, "required": []}},
        {"name": "get_customer_info", "description": "Get customer details", "input_schema": {"type": "object", "properties": {"customer_id": {"type": "integer"}}, "required": ["customer_id"]}},
        {"name": "get_customer_history", "description": "Get recent invoices for a customer", "input_schema": {"type": "object", "properties": {"customer_id": {"type": "integer"}, "limit": {"type": "integer", "default": 10}}, "required": ["customer_id"]}},
        {"name": "get_top_selling_products", "description": "Get top products by revenue or quantity", "input_schema": {"type": "object", "properties": {"limit": {"type": "integer", "default": 10}, "by": {"type": "string", "enum": ["quantity", "revenue"]}}, "required": []}},
        {"name": "get_unpaid_invoices", "description": "Get unpaid/partial invoices", "input_schema": {"type": "object", "properties": {"customer_id": {"type": "integer"}}, "required": []}},
        {"name": "search_customers", "description": "Search customers by name", "input_schema": {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]}},
        {"name": "search_products", "description": "Search products by name", "input_schema": {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]}},
        {"name": "create_invoice", "description": "Create a sales invoice", "input_schema": {"type": "object", "properties": {"customer_id": {"type": "integer"}, "items": {"type": "array", "items": {"type": "object", "properties": {"product_id": {"type": "integer"}, "quantity": {"type": "number"}, "unit_price": {"type": "number"}, "unit_type": {"type": "string", "default": "meter"}, "discount": {"type": "number", "default": 0}}, "required": ["product_id", "quantity"]}}, "payment_type": {"type": "string", "enum": ["cash", "credit", "mixed"], "default": "cash"}, "warehouse_id": {"type": "integer", "default": 1}, "discount": {"type": "number", "default": 0}, "paid_amount": {"type": "number"}, "notes": {"type": "string"}}, "required": ["items"]}},
        {"name": "cancel_invoice", "description": "Cancel an invoice and restore stock", "input_schema": {"type": "object", "properties": {"invoice_id": {"type": "integer"}, "reason": {"type": "string"}}, "required": ["invoice_id"]}},
        {"name": "apply_discount", "description": "Apply discount to an invoice", "input_schema": {"type": "object", "properties": {"invoice_id": {"type": "integer"}, "discount_amount": {"type": "number"}}, "required": ["invoice_id", "discount_amount"]}},
        {"name": "record_payment", "description": "Record customer payment against invoice", "input_schema": {"type": "object", "properties": {"customer_id": {"type": "integer"}, "invoice_id": {"type": "integer"}, "amount": {"type": "number"}, "notes": {"type": "string"}}, "required": ["customer_id", "invoice_id", "amount"]}},
        {"name": "refund_payment", "description": "Refund money to customer", "input_schema": {"type": "object", "properties": {"invoice_id": {"type": "integer"}, "amount": {"type": "number"}, "reason": {"type": "string"}}, "required": ["invoice_id", "amount"]}},
        {"name": "create_customer", "description": "Create a new customer", "input_schema": {"type": "object", "properties": {"name": {"type": "string"}, "phone": {"type": "string"}, "address": {"type": "string"}, "credit_limit": {"type": "number", "default": 0}, "payment_terms": {"type": "integer", "default": 0}, "notes": {"type": "string"}}, "required": ["name"]}},
        {"name": "update_customer", "description": "Update customer info", "input_schema": {"type": "object", "properties": {"customer_id": {"type": "integer"}, "name": {"type": "string"}, "phone": {"type": "string"}, "address": {"type": "string"}, "credit_limit": {"type": "number"}, "payment_terms": {"type": "integer"}, "notes": {"type": "string"}}, "required": ["customer_id"]}},
    ]

    def executor(tool_name, tool_input):
        mapping = {
            "get_today_sales": lambda **_: sales.get_today_sales(),
            "get_customer_info": lambda **p: sales.get_customer_info(p["customer_id"]),
            "get_customer_history": lambda **p: sales.get_customer_history(p["customer_id"], p.get("limit", 10)),
            "get_top_selling_products": lambda **p: sales.get_top_selling_products(p.get("limit", 10), p.get("by", "revenue")),
            "get_unpaid_invoices": lambda **p: sales.get_unpaid_invoices(p.get("customer_id")),
            "search_customers": lambda **p: retriever.search_customers(p["query"]),
            "search_products": lambda **p: retriever.search_products(p["query"]),
            "create_invoice": lambda **p: actions.create_invoice(customer_id=p.get("customer_id"), items=p["items"], payment_type=p.get("payment_type", "cash"), warehouse_id=p.get("warehouse_id", 1), discount=p.get("discount", 0), paid_amount=p.get("paid_amount"), notes=p.get("notes")),
            "cancel_invoice": lambda **p: actions.cancel_invoice(p["invoice_id"], p.get("reason")),
            "apply_discount": lambda **p: actions.apply_discount(p["invoice_id"], p["discount_amount"]),
            "record_payment": lambda **p: actions.record_payment(customer_id=p["customer_id"], invoice_id=p["invoice_id"], amount=p["amount"], notes=p.get("notes")),
            "refund_payment": lambda **p: actions.refund_payment(p["invoice_id"], p["amount"], p.get("reason")),
            "create_customer": lambda **p: actions.create_customer(name=p["name"], phone=p.get("phone"), address=p.get("address"), credit_limit=p.get("credit_limit", 0), payment_terms=p.get("payment_terms", 0), notes=p.get("notes")),
            "update_customer": lambda **p: actions.update_customer(customer_id=p["customer_id"], name=p.get("name"), phone=p.get("phone"), address=p.get("address"), credit_limit=p.get("credit_limit"), payment_terms=p.get("payment_terms"), notes=p.get("notes")),
        }
        fn = mapping.get(tool_name)
        if not fn:
            return json.dumps({"error": f"Unknown tool: {tool_name}"})
        try:
            return json.dumps(fn(**tool_input), default=str)
        except Exception as e:
            return json.dumps({"error": str(e)})

    return SubAgent(db, SALES_AGENT_PROMPT, tools, executor)


def build_inventory_agent(db: Session) -> SubAgent:
    from app.ai.tools.stock_tools import StockTools
    from app.ai.tools.action_tools import ActionTools
    from app.ai.rag.retriever import ERPContextRetriever

    stock = StockTools(db)
    actions = ActionTools(db)
    retriever = ERPContextRetriever(db)

    tools = [
        {"name": "get_stock_level", "description": "Get stock level for a product", "input_schema": {"type": "object", "properties": {"product_id": {"type": "integer"}, "warehouse_id": {"type": "integer"}}, "required": ["product_id"]}},
        {"name": "get_low_stock_items", "description": "Get items below threshold", "input_schema": {"type": "object", "properties": {"threshold": {"type": "number", "default": 10}}, "required": []}},
        {"name": "get_stock_movement_history", "description": "Get movement history for a product", "input_schema": {"type": "object", "properties": {"product_id": {"type": "integer"}, "limit": {"type": "integer", "default": 20}}, "required": ["product_id"]}},
        {"name": "get_warehouse_summary", "description": "Get warehouse stock summary", "input_schema": {"type": "object", "properties": {"warehouse_id": {"type": "integer"}}, "required": ["warehouse_id"]}},
        {"name": "get_dead_stock", "description": "Get products with no movement", "input_schema": {"type": "object", "properties": {"days": {"type": "integer", "default": 30}}, "required": []}},
        {"name": "get_stock_valuation", "description": "Get inventory valuation", "input_schema": {"type": "object", "properties": {"warehouse_id": {"type": "integer"}}, "required": []}},
        {"name": "search_products", "description": "Search products by name", "input_schema": {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]}},
        {"name": "update_stock", "description": "Add stock (receive goods)", "input_schema": {"type": "object", "properties": {"product_id": {"type": "integer"}, "warehouse_id": {"type": "integer"}, "quantity": {"type": "number"}, "cost_per_unit": {"type": "number", "default": 0}, "notes": {"type": "string"}}, "required": ["product_id", "warehouse_id", "quantity"]}},
        {"name": "transfer_stock", "description": "Transfer stock between warehouses", "input_schema": {"type": "object", "properties": {"product_id": {"type": "integer"}, "from_warehouse_id": {"type": "integer"}, "to_warehouse_id": {"type": "integer"}, "quantity": {"type": "number"}, "notes": {"type": "string"}}, "required": ["product_id", "from_warehouse_id", "to_warehouse_id", "quantity"]}},
        {"name": "adjust_stock", "description": "Set stock to a specific quantity", "input_schema": {"type": "object", "properties": {"product_id": {"type": "integer"}, "warehouse_id": {"type": "integer"}, "new_quantity": {"type": "number"}, "reason": {"type": "string"}}, "required": ["product_id", "warehouse_id", "new_quantity"]}},
    ]

    def executor(tool_name, tool_input):
        mapping = {
            "get_stock_level": lambda **p: stock.get_stock_level(p["product_id"], p.get("warehouse_id")),
            "get_low_stock_items": lambda **p: stock.get_low_stock_items(p.get("threshold", 10)),
            "get_stock_movement_history": lambda **p: stock.get_stock_movement_history(p["product_id"], p.get("limit", 20)),
            "get_warehouse_summary": lambda **p: stock.get_warehouse_summary(p["warehouse_id"]),
            "get_dead_stock": lambda **p: stock.get_dead_stock(p.get("days", 30)),
            "get_stock_valuation": lambda **p: stock.get_stock_valuation(p.get("warehouse_id")),
            "search_products": lambda **p: retriever.search_products(p["query"]),
            "update_stock": lambda **p: actions.update_stock(product_id=p["product_id"], warehouse_id=p["warehouse_id"], quantity=p["quantity"], cost_per_unit=p.get("cost_per_unit", 0), notes=p.get("notes")),
            "transfer_stock": lambda **p: actions.transfer_stock(product_id=p["product_id"], from_warehouse_id=p["from_warehouse_id"], to_warehouse_id=p["to_warehouse_id"], quantity=p["quantity"], notes=p.get("notes")),
            "adjust_stock": lambda **p: actions.adjust_stock(product_id=p["product_id"], warehouse_id=p["warehouse_id"], new_quantity=p["new_quantity"], reason=p.get("reason", "manual_adjustment")),
        }
        fn = mapping.get(tool_name)
        if not fn:
            return json.dumps({"error": f"Unknown tool: {tool_name}"})
        try:
            return json.dumps(fn(**tool_input), default=str)
        except Exception as e:
            return json.dumps({"error": str(e)})

    return SubAgent(db, INVENTORY_AGENT_PROMPT, tools, executor)


def build_accounting_agent(db: Session) -> SubAgent:
    from app.ai.tools.finance_tools import FinanceTools
    from app.ai.tools.reporting_tools import ReportingTools

    finance = FinanceTools(db)
    reporting = ReportingTools(db)

    tools = [
        {"name": "get_profit_and_loss", "description": "Get P&L report for a period", "input_schema": {"type": "object", "properties": {"start_date": {"type": "string"}, "end_date": {"type": "string"}}, "required": ["start_date", "end_date"]}},
        {"name": "get_cash_balance", "description": "Get current cash balance", "input_schema": {"type": "object", "properties": {}, "required": []}},
        {"name": "get_receivables_summary", "description": "Get accounts receivable with top debtors", "input_schema": {"type": "object", "properties": {}, "required": []}},
        {"name": "get_payables_summary", "description": "Get accounts payable with top creditors", "input_schema": {"type": "object", "properties": {}, "required": []}},
        {"name": "get_expense_breakdown", "description": "Get expenses by category", "input_schema": {"type": "object", "properties": {"start_date": {"type": "string"}, "end_date": {"type": "string"}}, "required": ["start_date", "end_date"]}},
        {"name": "get_daily_revenue", "description": "Get daily revenue trend", "input_schema": {"type": "object", "properties": {"start_date": {"type": "string"}, "end_date": {"type": "string"}}, "required": ["start_date", "end_date"]}},
        {"name": "demand_forecast", "description": "Predict demand and stockout for a product", "input_schema": {"type": "object", "properties": {"product_id": {"type": "integer"}, "days_back": {"type": "integer", "default": 30}}, "required": ["product_id"]}},
    ]

    def executor(tool_name, tool_input):
        mapping = {
            "get_profit_and_loss": lambda **p: finance.get_profit_and_loss(p["start_date"], p["end_date"]),
            "get_cash_balance": lambda **_: finance.get_cash_balance(),
            "get_receivables_summary": lambda **_: finance.get_receivables_summary(),
            "get_payables_summary": lambda **_: finance.get_payables_summary(),
            "get_expense_breakdown": lambda **p: finance.get_expense_breakdown(p["start_date"], p["end_date"]),
            "get_daily_revenue": lambda **p: finance.get_daily_revenue(p["start_date"], p["end_date"]),
            "demand_forecast": lambda **p: reporting.demand_forecast(p["product_id"], p.get("days_back", 30)),
        }
        fn = mapping.get(tool_name)
        if not fn:
            return json.dumps({"error": f"Unknown tool: {tool_name}"})
        try:
            return json.dumps(fn(**tool_input), default=str)
        except Exception as e:
            return json.dumps({"error": str(e)})

    return SubAgent(db, ACCOUNTING_AGENT_PROMPT, tools, executor)
