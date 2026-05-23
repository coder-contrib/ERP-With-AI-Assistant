from sqlalchemy.orm import Session
from app.ai.agents.sales_agent import SalesAgent
from app.ai.agents.inventory_agent import InventoryAgent
from app.ai.agents.accounting_agent import AccountingAgent
from app.ai.tools.reporting_tools import ReportingTools
from app.ai.prompts.system_prompts import MANAGER_AGENT_PROMPT


class ManagerAgent:
    """Meta-agent that routes queries to specialized agents.
    Acts as the main AI interface — determines intent and delegates.
    """

    def __init__(self, db: Session):
        self.db = db
        self.system_prompt = MANAGER_AGENT_PROMPT
        self.agents = {
            "sales": SalesAgent(db),
            "inventory": InventoryAgent(db),
            "accounting": AccountingAgent(db),
        }
        self.reporting = ReportingTools(db)

    def classify_intent(self, query: str) -> str:
        query_lower = query.lower()
        inventory_keywords = ["stock", "quantity", "warehouse", "available", "meters", "pieces", "carton", "low stock", "dead stock", "transfer"]
        sales_keywords = ["sale", "sold", "invoice", "customer", "revenue", "top selling", "best selling", "unpaid"]
        accounting_keywords = ["profit", "loss", "expense", "cash", "balance", "receivable", "payable", "margin", "cost", "financial"]

        scores = {"inventory": 0, "sales": 0, "accounting": 0}
        for kw in inventory_keywords:
            if kw in query_lower:
                scores["inventory"] += 1
        for kw in sales_keywords:
            if kw in query_lower:
                scores["sales"] += 1
        for kw in accounting_keywords:
            if kw in query_lower:
                scores["accounting"] += 1

        if max(scores.values()) == 0:
            return "sales"
        return max(scores, key=scores.get)

    def get_tools_schema(self) -> list[dict]:
        all_tools = []
        for agent_type, agent in self.agents.items():
            for tool in agent.get_tools_schema():
                tool["agent"] = agent_type
                all_tools.append(tool)
        return all_tools

    def execute_query(self, query: str) -> dict:
        intent = self.classify_intent(query)
        agent = self.agents.get(intent)
        return {
            "intent": intent,
            "agent": intent,
            "tools_available": [t["name"] for t in agent.get_tools_schema()],
            "system_prompt": agent.system_prompt,
        }
