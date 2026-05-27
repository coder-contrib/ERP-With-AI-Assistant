import anthropic
import json
from sqlalchemy.orm import Session
from app.config import settings
from app.ai.agents.sub_agents import build_sales_agent, build_inventory_agent, build_accounting_agent
from app.ai.memory.conversation import ConversationMemory
from app.ai.prompts.system_prompts import MANAGER_AGENT_PROMPT
import logging

logger = logging.getLogger(__name__)


class ManagerAgent:
    """Orchestrator agent that delegates to specialized sub-agents.
    The Manager understands user intent and routes to the right domain agent.
    Each sub-agent runs its own Claude tool loop independently.
    """

    def __init__(self, db: Session):
        self.db = db
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self.model = settings.ai_model

    def get_tools(self) -> list[dict]:
        return [
            # ─── Delegation Meta-Tools ────────────────────────────────────
            {
                "name": "delegate_to_sales_agent",
                "description": "Delegate a sales/CRM task to the Sales Agent. Use for: creating invoices, recording payments, refunds, discounts, customer management, and sales queries (today's sales, customer history, unpaid invoices, top products). The Sales Agent has full access to sales tools and will execute multi-step operations autonomously.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "task": {
                            "type": "string",
                            "description": "Clear description of what needs to be done. Include all relevant details (customer name/ID, product names/IDs, quantities, amounts). Example: 'Create invoice for customer Ahmed (ID 5): 10 meters of Royal Ceramica (product 12) at 150 EGP/meter, cash payment'"
                        }
                    },
                    "required": ["task"]
                },
            },
            {
                "name": "delegate_to_inventory_agent",
                "description": "Delegate an inventory/warehouse task to the Inventory Agent. Use for: checking stock levels, receiving goods, transferring between warehouses, stock adjustments, low stock alerts, dead stock reports, stock valuation. The Inventory Agent has full access to inventory tools.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "task": {
                            "type": "string",
                            "description": "Clear description of the inventory operation. Include product names/IDs, warehouse IDs, quantities. Example: 'Transfer 50 meters of product 8 from warehouse 1 to warehouse 2'"
                        }
                    },
                    "required": ["task"]
                },
            },
            {
                "name": "delegate_to_accounting_agent",
                "description": "Delegate a financial/accounting query to the Accounting Agent. Use for: profit & loss reports, cash balance, receivables/payables, expense breakdowns, revenue trends, demand forecasting. The Accounting Agent handles all financial analysis.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "task": {
                            "type": "string",
                            "description": "Clear description of the financial query. Include date ranges if relevant. Example: 'Get profit and loss report for May 2024 and highlight any concerning trends'"
                        }
                    },
                    "required": ["task"]
                },
            },
            # ─── Quick Lookup Tools (Manager keeps these for fast routing) ───
            {
                "name": "search_products",
                "description": "Quick search for products by name. Use this to resolve product names to IDs before delegating.",
                "input_schema": {
                    "type": "object",
                    "properties": {"query": {"type": "string"}},
                    "required": ["query"]
                },
            },
            {
                "name": "search_customers",
                "description": "Quick search for customers by name. Use this to resolve customer names to IDs before delegating.",
                "input_schema": {
                    "type": "object",
                    "properties": {"query": {"type": "string"}},
                    "required": ["query"]
                },
            },
        ]

    def execute_tool(self, tool_name: str, tool_input: dict) -> str:
        if tool_name == "delegate_to_sales_agent":
            return self._delegate_sales(tool_input["task"])
        elif tool_name == "delegate_to_inventory_agent":
            return self._delegate_inventory(tool_input["task"])
        elif tool_name == "delegate_to_accounting_agent":
            return self._delegate_accounting(tool_input["task"])
        elif tool_name == "search_products":
            return self._search_products(tool_input["query"])
        elif tool_name == "search_customers":
            return self._search_customers(tool_input["query"])
        else:
            return json.dumps({"error": f"Unknown tool: {tool_name}"})

    def _delegate_sales(self, task: str) -> str:
        try:
            agent = build_sales_agent(self.db)
            result = agent.execute(task)
            return json.dumps({"agent": "sales", "result": result})
        except Exception as e:
            logger.error(f"Sales agent error: {e}")
            return json.dumps({"error": f"Sales agent failed: {str(e)}"})

    def _delegate_inventory(self, task: str) -> str:
        try:
            agent = build_inventory_agent(self.db)
            result = agent.execute(task)
            return json.dumps({"agent": "inventory", "result": result})
        except Exception as e:
            logger.error(f"Inventory agent error: {e}")
            return json.dumps({"error": f"Inventory agent failed: {str(e)}"})

    def _delegate_accounting(self, task: str) -> str:
        try:
            agent = build_accounting_agent(self.db)
            result = agent.execute(task)
            return json.dumps({"agent": "accounting", "result": result})
        except Exception as e:
            logger.error(f"Accounting agent error: {e}")
            return json.dumps({"error": f"Accounting agent failed: {str(e)}"})

    def _search_products(self, query: str) -> str:
        from app.ai.rag.retriever import ERPContextRetriever
        retriever = ERPContextRetriever(self.db)
        try:
            result = retriever.search_products(query)
            return json.dumps(result, default=str)
        except Exception as e:
            return json.dumps({"error": str(e)})

    def _search_customers(self, query: str) -> str:
        from app.ai.rag.retriever import ERPContextRetriever
        retriever = ERPContextRetriever(self.db)
        try:
            result = retriever.search_customers(query)
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

        while response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    logger.info(f"Manager calling tool: {block.name}")
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

        assistant_text = ""
        for block in response.content:
            if hasattr(block, "text"):
                assistant_text += block.text

        memory.add_assistant_message(assistant_text)
        return assistant_text
