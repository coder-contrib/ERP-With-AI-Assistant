import anthropic
import json
from app.config import settings
from app.ai.memory.conversation import ConversationMemory
from app.ai.prompts.system_prompts import MANAGER_AGENT_PROMPT
from sqlalchemy.orm import Session
from typing import AsyncGenerator
import logging

logger = logging.getLogger(__name__)


class ClaudeClient:
    """Claude AI client for the ERP assistant.
    Uses Claude Sonnet for business reasoning and tool use.
    """

    def __init__(self, db: Session):
        self.db = db
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self.model = settings.ai_model

    def get_tools(self) -> list[dict]:
        return [
            {
                "name": "get_today_sales",
                "description": "Get today's sales summary including invoice count, total amount, and cash collected",
                "input_schema": {"type": "object", "properties": {}, "required": []},
            },
            {
                "name": "get_customer_info",
                "description": "Get customer details including name, balance, credit limit, and payment terms",
                "input_schema": {"type": "object", "properties": {"customer_id": {"type": "integer", "description": "Customer ID"}}, "required": ["customer_id"]},
            },
            {
                "name": "get_stock_level",
                "description": "Get current stock level for a product across warehouses",
                "input_schema": {"type": "object", "properties": {"product_id": {"type": "integer"}, "warehouse_id": {"type": "integer", "description": "Optional warehouse filter"}}, "required": ["product_id"]},
            },
            {
                "name": "get_low_stock_items",
                "description": "Get products with stock below a threshold",
                "input_schema": {"type": "object", "properties": {"threshold": {"type": "number", "default": 10}}, "required": []},
            },
            {
                "name": "get_profit_and_loss",
                "description": "Get profit and loss report for a date range with revenue, COGS, expenses, and net profit",
                "input_schema": {"type": "object", "properties": {"start_date": {"type": "string", "description": "YYYY-MM-DD"}, "end_date": {"type": "string", "description": "YYYY-MM-DD"}}, "required": ["start_date", "end_date"]},
            },
            {
                "name": "get_cash_balance",
                "description": "Get current cash balance (total in minus total out)",
                "input_schema": {"type": "object", "properties": {}, "required": []},
            },
            {
                "name": "get_top_selling_products",
                "description": "Get top selling products by revenue or quantity",
                "input_schema": {"type": "object", "properties": {"limit": {"type": "integer", "default": 10}, "by": {"type": "string", "enum": ["quantity", "revenue"], "default": "revenue"}}, "required": []},
            },
            {
                "name": "get_customer_history",
                "description": "Get recent purchase history for a customer",
                "input_schema": {"type": "object", "properties": {"customer_id": {"type": "integer"}, "limit": {"type": "integer", "default": 10}}, "required": ["customer_id"]},
            },
            {
                "name": "get_unpaid_invoices",
                "description": "Get list of unpaid or partially paid invoices",
                "input_schema": {"type": "object", "properties": {"customer_id": {"type": "integer", "description": "Optional filter by customer"}}, "required": []},
            },
            {
                "name": "get_receivables_summary",
                "description": "Get accounts receivable summary with top debtors",
                "input_schema": {"type": "object", "properties": {}, "required": []},
            },
            {
                "name": "get_payables_summary",
                "description": "Get accounts payable summary with top creditors",
                "input_schema": {"type": "object", "properties": {}, "required": []},
            },
            {
                "name": "get_expense_breakdown",
                "description": "Get expenses grouped by category for a period",
                "input_schema": {"type": "object", "properties": {"start_date": {"type": "string"}, "end_date": {"type": "string"}}, "required": ["start_date", "end_date"]},
            },
            {
                "name": "demand_forecast",
                "description": "Predict demand and days until stockout for a product",
                "input_schema": {"type": "object", "properties": {"product_id": {"type": "integer"}, "days_back": {"type": "integer", "default": 30}}, "required": ["product_id"]},
            },
            {
                "name": "search_products",
                "description": "Search products by name",
                "input_schema": {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]},
            },
            {
                "name": "search_customers",
                "description": "Search customers by name",
                "input_schema": {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]},
            },
        ]

    def execute_tool(self, tool_name: str, tool_input: dict) -> str:
        from app.ai.tools.sales_tools import SalesTools
        from app.ai.tools.stock_tools import StockTools
        from app.ai.tools.finance_tools import FinanceTools
        from app.ai.tools.reporting_tools import ReportingTools
        from app.ai.rag.retriever import ERPContextRetriever

        sales = SalesTools(self.db)
        stock = StockTools(self.db)
        finance = FinanceTools(self.db)
        reporting = ReportingTools(self.db)
        retriever = ERPContextRetriever(self.db)

        tool_map = {
            "get_today_sales": lambda **_: sales.get_today_sales(),
            "get_customer_info": lambda **p: sales.get_customer_info(p["customer_id"]),
            "get_customer_history": lambda **p: sales.get_customer_history(p["customer_id"], p.get("limit", 10)),
            "get_top_selling_products": lambda **p: sales.get_top_selling_products(p.get("limit", 10), p.get("by", "revenue")),
            "get_unpaid_invoices": lambda **p: sales.get_unpaid_invoices(p.get("customer_id")),
            "get_stock_level": lambda **p: stock.get_stock_level(p["product_id"], p.get("warehouse_id")),
            "get_low_stock_items": lambda **p: stock.get_low_stock_items(p.get("threshold", 10)),
            "get_profit_and_loss": lambda **p: finance.get_profit_and_loss(p["start_date"], p["end_date"]),
            "get_cash_balance": lambda **_: finance.get_cash_balance(),
            "get_receivables_summary": lambda **_: finance.get_receivables_summary(),
            "get_payables_summary": lambda **_: finance.get_payables_summary(),
            "get_expense_breakdown": lambda **p: finance.get_expense_breakdown(p["start_date"], p["end_date"]),
            "demand_forecast": lambda **p: reporting.demand_forecast(p["product_id"], p.get("days_back", 30)),
            "search_products": lambda **p: retriever.search_products(p["query"]),
            "search_customers": lambda **p: retriever.search_customers(p["query"]),
        }

        fn = tool_map.get(tool_name)
        if not fn:
            return json.dumps({"error": f"Unknown tool: {tool_name}"})

        try:
            result = fn(**tool_input)
            return json.dumps(result, default=str)
        except Exception as e:
            return json.dumps({"error": str(e)})

    def chat(self, session_id: str, user_message: str) -> str:
        memory = ConversationMemory(session_id)
        memory.add_user_message(user_message)
        history = memory.get_context_window(max_messages=20)

        messages = []
        for msg in history:
            if msg["role"] in ("user", "assistant"):
                messages.append({"role": msg["role"], "content": msg["content"]})

        response = self.client.messages.create(
            model=self.model,
            max_tokens=4096,
            system=MANAGER_AGENT_PROMPT,
            tools=self.get_tools(),
            messages=messages,
        )

        # Handle tool use loop
        while response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    result = self.execute_tool(block.name, block.input)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result,
                    })
                    memory.add_tool_result(block.name, json.loads(result))

            messages.append({"role": "assistant", "content": response.content})
            messages.append({"role": "user", "content": tool_results})

            response = self.client.messages.create(
                model=self.model,
                max_tokens=4096,
                system=MANAGER_AGENT_PROMPT,
                tools=self.get_tools(),
                messages=messages,
            )

        # Extract text response
        assistant_text = ""
        for block in response.content:
            if hasattr(block, "text"):
                assistant_text += block.text

        memory.add_assistant_message(assistant_text)
        return assistant_text

    async def chat_stream(self, session_id: str, user_message: str) -> AsyncGenerator[str, None]:
        memory = ConversationMemory(session_id)
        memory.add_user_message(user_message)
        history = memory.get_context_window(max_messages=20)

        messages = []
        for msg in history:
            if msg["role"] in ("user", "assistant"):
                messages.append({"role": msg["role"], "content": msg["content"]})

        # First call (may need tool use)
        response = self.client.messages.create(
            model=self.model,
            max_tokens=4096,
            system=MANAGER_AGENT_PROMPT,
            tools=self.get_tools(),
            messages=messages,
        )

        # Handle tool use (non-streaming for tool calls)
        while response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    yield json.dumps({"type": "tool_call", "tool": block.name}) + "\n"
                    result = self.execute_tool(block.name, block.input)
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
                system=MANAGER_AGENT_PROMPT,
                tools=self.get_tools(),
                messages=messages,
            )

        # Stream final text response
        full_text = ""
        with self.client.messages.stream(
            model=self.model,
            max_tokens=4096,
            system=MANAGER_AGENT_PROMPT,
            messages=messages + [{"role": "assistant", "content": [{"type": "text", "text": ""}]}] if response.stop_reason == "tool_use" else messages,
        ) as stream:
            for text in stream.text_stream:
                full_text += text
                yield json.dumps({"type": "token", "text": text}) + "\n"

        if not full_text:
            for block in response.content:
                if hasattr(block, "text"):
                    full_text += block.text
                    yield json.dumps({"type": "token", "text": block.text}) + "\n"

        memory.add_assistant_message(full_text)
        yield json.dumps({"type": "done", "full_text": full_text}) + "\n"
