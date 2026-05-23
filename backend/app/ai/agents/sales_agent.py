from sqlalchemy.orm import Session
from app.ai.tools.sales_tools import SalesTools
from app.ai.prompts.system_prompts import SALES_AGENT_PROMPT


class SalesAgent:
    """AI agent specialized in sales operations.
    Accesses data ONLY through service layer tools.
    """

    def __init__(self, db: Session):
        self.tools = SalesTools(db)
        self.system_prompt = SALES_AGENT_PROMPT

    def get_tools_schema(self) -> list[dict]:
        return [
            {
                "name": "get_today_sales",
                "description": "Get today's sales summary including count and total amount",
                "parameters": {},
            },
            {
                "name": "get_customer_info",
                "description": "Get customer details including balance and credit limit",
                "parameters": {"customer_id": "int"},
            },
            {
                "name": "get_customer_history",
                "description": "Get recent purchase history for a customer",
                "parameters": {"customer_id": "int", "limit": "int (default 10)"},
            },
            {
                "name": "get_top_selling_products",
                "description": "Get top selling products by quantity or revenue",
                "parameters": {"limit": "int (default 10)", "by": "'quantity' or 'revenue'"},
            },
            {
                "name": "get_sales_by_period",
                "description": "Get sales aggregated by day/week/month",
                "parameters": {"start_date": "str", "end_date": "str"},
            },
            {
                "name": "get_unpaid_invoices",
                "description": "Get list of unpaid or partially paid invoices",
                "parameters": {"customer_id": "int (optional)"},
            },
        ]

    def execute_tool(self, tool_name: str, params: dict) -> dict:
        tool_map = {
            "get_today_sales": self.tools.get_today_sales,
            "get_customer_info": self.tools.get_customer_info,
            "get_customer_history": self.tools.get_customer_history,
            "get_top_selling_products": self.tools.get_top_selling_products,
            "get_sales_by_period": self.tools.get_sales_by_period,
            "get_unpaid_invoices": self.tools.get_unpaid_invoices,
        }
        tool = tool_map.get(tool_name)
        if not tool:
            return {"error": f"Unknown tool: {tool_name}"}
        return tool(**params)
