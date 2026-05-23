from sqlalchemy.orm import Session
from app.ai.tools.finance_tools import FinanceTools
from app.ai.prompts.system_prompts import ACCOUNTING_AGENT_PROMPT


class AccountingAgent:
    """AI agent specialized in financial and accounting operations.
    Accesses data ONLY through service layer tools.
    """

    def __init__(self, db: Session):
        self.tools = FinanceTools(db)
        self.system_prompt = ACCOUNTING_AGENT_PROMPT

    def get_tools_schema(self) -> list[dict]:
        return [
            {
                "name": "get_profit_and_loss",
                "description": "Get profit and loss report for a date range",
                "parameters": {"start_date": "str", "end_date": "str"},
            },
            {
                "name": "get_cash_balance",
                "description": "Get current cash balance",
                "parameters": {},
            },
            {
                "name": "get_receivables_summary",
                "description": "Get accounts receivable summary",
                "parameters": {},
            },
            {
                "name": "get_payables_summary",
                "description": "Get accounts payable summary",
                "parameters": {},
            },
            {
                "name": "get_expense_breakdown",
                "description": "Get expenses grouped by category for a period",
                "parameters": {"start_date": "str", "end_date": "str"},
            },
            {
                "name": "get_daily_revenue",
                "description": "Get daily revenue trend for a period",
                "parameters": {"start_date": "str", "end_date": "str"},
            },
        ]

    def execute_tool(self, tool_name: str, params: dict) -> dict:
        tool_map = {
            "get_profit_and_loss": self.tools.get_profit_and_loss,
            "get_cash_balance": self.tools.get_cash_balance,
            "get_receivables_summary": self.tools.get_receivables_summary,
            "get_payables_summary": self.tools.get_payables_summary,
            "get_expense_breakdown": self.tools.get_expense_breakdown,
            "get_daily_revenue": self.tools.get_daily_revenue,
        }
        tool = tool_map.get(tool_name)
        if not tool:
            return {"error": f"Unknown tool: {tool_name}"}
        return tool(**params)
