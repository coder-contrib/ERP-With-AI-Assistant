from sqlalchemy.orm import Session
from app.ai.tools.stock_tools import StockTools
from app.ai.prompts.system_prompts import INVENTORY_AGENT_PROMPT


class InventoryAgent:
    """AI agent specialized in inventory operations.
    Accesses data ONLY through service layer tools.
    """

    def __init__(self, db: Session):
        self.tools = StockTools(db)
        self.system_prompt = INVENTORY_AGENT_PROMPT

    def get_tools_schema(self) -> list[dict]:
        return [
            {
                "name": "get_stock_level",
                "description": "Get current stock level for a product in a specific warehouse",
                "parameters": {"product_id": "int", "warehouse_id": "int (optional)"},
            },
            {
                "name": "get_low_stock_items",
                "description": "Get products below a threshold quantity",
                "parameters": {"threshold": "float (default 10)"},
            },
            {
                "name": "get_stock_movement_history",
                "description": "Get recent stock movements for a product",
                "parameters": {"product_id": "int", "limit": "int (default 20)"},
            },
            {
                "name": "get_warehouse_summary",
                "description": "Get stock summary for a warehouse",
                "parameters": {"warehouse_id": "int"},
            },
            {
                "name": "get_dead_stock",
                "description": "Get products with no movement in X days",
                "parameters": {"days": "int (default 30)"},
            },
            {
                "name": "get_stock_valuation",
                "description": "Get total inventory value by warehouse",
                "parameters": {"warehouse_id": "int (optional)"},
            },
        ]

    def execute_tool(self, tool_name: str, params: dict) -> dict:
        tool_map = {
            "get_stock_level": self.tools.get_stock_level,
            "get_low_stock_items": self.tools.get_low_stock_items,
            "get_stock_movement_history": self.tools.get_stock_movement_history,
            "get_warehouse_summary": self.tools.get_warehouse_summary,
            "get_dead_stock": self.tools.get_dead_stock,
            "get_stock_valuation": self.tools.get_stock_valuation,
        }
        tool = tool_map.get(tool_name)
        if not tool:
            return {"error": f"Unknown tool: {tool_name}"}
        return tool(**params)
