from sqlalchemy.orm import Session
from app.ai.agents.sales_agent import SalesAgent
from app.ai.agents.inventory_agent import InventoryAgent
from app.ai.agents.accounting_agent import AccountingAgent
from app.core.redis import get_redis
from app.services.cache_service import CacheService


class AIService:
    """Orchestrates AI agents.
    Routes queries to the appropriate agent based on intent.
    Manages conversation memory via Redis.
    """

    def __init__(self, db: Session):
        self.db = db
        self.cache = CacheService(get_redis())
        self.agents = {
            "sales": SalesAgent(db),
            "inventory": InventoryAgent(db),
            "accounting": AccountingAgent(db),
        }

    def get_agent(self, agent_type: str):
        return self.agents.get(agent_type)

    def execute_tool(self, agent_type: str, tool_name: str, params: dict) -> dict:
        agent = self.get_agent(agent_type)
        if not agent:
            return {"error": f"Unknown agent: {agent_type}"}
        return agent.execute_tool(tool_name, params)

    def get_conversation(self, session_id: str) -> list:
        return self.cache.get_ai_conversation(session_id) or []

    def add_message(self, session_id: str, role: str, content: str):
        self.cache.append_ai_message(session_id, {"role": role, "content": content})

    def clear_conversation(self, session_id: str):
        self.cache.clear_ai_conversation(session_id)
