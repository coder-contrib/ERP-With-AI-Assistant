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
            # ─── Read Tools (Sales) ──────────────────────────────────────────
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
            # ─── Action Tools (Sales) ────────────────────────────────────────
            {
                "name": "create_invoice",
                "description": "Create a new sales invoice. Validates stock, deducts inventory, creates ledger entries, and records payment. Items is an array of objects with product_id, quantity, and optionally unit_price, unit_type, discount.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "customer_id": {"type": "integer", "description": "Customer ID (null for walk-in)"},
                        "items": {
                            "type": "array",
                            "description": "List of items to sell",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "product_id": {"type": "integer"},
                                    "quantity": {"type": "number"},
                                    "unit_price": {"type": "number", "description": "Optional, uses product selling price if omitted"},
                                    "unit_type": {"type": "string", "default": "meter"},
                                    "discount": {"type": "number", "default": 0},
                                },
                                "required": ["product_id", "quantity"],
                            },
                        },
                        "payment_type": {"type": "string", "enum": ["cash", "credit", "mixed"], "default": "cash"},
                        "warehouse_id": {"type": "integer", "default": 1},
                        "discount": {"type": "number", "default": 0, "description": "Overall invoice discount"},
                        "paid_amount": {"type": "number", "description": "Amount paid now. Defaults to full amount for cash, 0 for credit"},
                        "notes": {"type": "string"},
                    },
                    "required": ["items"],
                },
            },
            {
                "name": "cancel_invoice",
                "description": "Cancel a sales invoice. Restores stock, reverses cash transactions, and updates customer balance.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "invoice_id": {"type": "integer", "description": "Invoice ID to cancel"},
                        "reason": {"type": "string", "description": "Reason for cancellation"},
                    },
                    "required": ["invoice_id"],
                },
            },
            {
                "name": "apply_discount",
                "description": "Apply or change discount on an existing invoice. Recalculates total and remaining amount.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "invoice_id": {"type": "integer"},
                        "discount_amount": {"type": "number", "description": "New discount amount in EGP"},
                    },
                    "required": ["invoice_id", "discount_amount"],
                },
            },
            # ─── Action Tools (Payments) ─────────────────────────────────────
            {
                "name": "record_payment",
                "description": "Record a customer payment against an invoice. Updates invoice status, customer balance, and cash ledger.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "customer_id": {"type": "integer"},
                        "invoice_id": {"type": "integer"},
                        "amount": {"type": "number", "description": "Payment amount in EGP"},
                        "notes": {"type": "string"},
                    },
                    "required": ["customer_id", "invoice_id", "amount"],
                },
            },
            {
                "name": "refund_payment",
                "description": "Refund money back to customer for an invoice. Creates cash-out transaction and updates balances.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "invoice_id": {"type": "integer"},
                        "amount": {"type": "number", "description": "Refund amount in EGP"},
                        "reason": {"type": "string"},
                    },
                    "required": ["invoice_id", "amount"],
                },
            },
            # ─── Action Tools (Inventory) ────────────────────────────────────
            {
                "name": "update_stock",
                "description": "Add stock (receive goods) for a product in a warehouse. Creates inventory transaction and updates cache.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "product_id": {"type": "integer"},
                        "warehouse_id": {"type": "integer"},
                        "quantity": {"type": "number", "description": "Quantity to add"},
                        "cost_per_unit": {"type": "number", "default": 0, "description": "Purchase cost per unit"},
                        "notes": {"type": "string"},
                    },
                    "required": ["product_id", "warehouse_id", "quantity"],
                },
            },
            {
                "name": "transfer_stock",
                "description": "Transfer stock between warehouses. Validates source availability and creates transfer record.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "product_id": {"type": "integer"},
                        "from_warehouse_id": {"type": "integer"},
                        "to_warehouse_id": {"type": "integer"},
                        "quantity": {"type": "number"},
                        "notes": {"type": "string"},
                    },
                    "required": ["product_id", "from_warehouse_id", "to_warehouse_id", "quantity"],
                },
            },
            {
                "name": "adjust_stock",
                "description": "Set stock to a specific quantity (manual correction). Use for physical count adjustments, wastage, or corrections.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "product_id": {"type": "integer"},
                        "warehouse_id": {"type": "integer"},
                        "new_quantity": {"type": "number", "description": "The corrected quantity after adjustment"},
                        "reason": {"type": "string", "description": "Reason for adjustment (e.g. physical_count, wastage, damage)"},
                    },
                    "required": ["product_id", "warehouse_id", "new_quantity"],
                },
            },
            # ─── Action Tools (CRM) ─────────────────────────────────────────
            {
                "name": "create_customer",
                "description": "Create a new customer record in the system.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string", "description": "Customer full name"},
                        "phone": {"type": "string"},
                        "address": {"type": "string"},
                        "credit_limit": {"type": "number", "default": 0, "description": "Maximum credit in EGP"},
                        "payment_terms": {"type": "integer", "default": 0, "description": "Payment terms in days"},
                        "notes": {"type": "string"},
                    },
                    "required": ["name"],
                },
            },
            {
                "name": "update_customer",
                "description": "Update an existing customer's information. Only provide fields that need to change.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "customer_id": {"type": "integer"},
                        "name": {"type": "string"},
                        "phone": {"type": "string"},
                        "address": {"type": "string"},
                        "credit_limit": {"type": "number"},
                        "payment_terms": {"type": "integer"},
                        "notes": {"type": "string"},
                    },
                    "required": ["customer_id"],
                },
            },
        ]

    def execute_tool(self, tool_name: str, tool_input: dict) -> str:
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

        tool_map = {
            # Read tools
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
            # Action tools - Sales
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
            # Action tools - Payments
            "record_payment": lambda **p: actions.record_payment(
                customer_id=p["customer_id"],
                invoice_id=p["invoice_id"],
                amount=p["amount"],
                notes=p.get("notes"),
            ),
            "refund_payment": lambda **p: actions.refund_payment(p["invoice_id"], p["amount"], p.get("reason")),
            # Action tools - Inventory
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
            # Action tools - CRM
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
