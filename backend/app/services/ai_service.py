from sqlalchemy.orm import Session
from app.ai.agents.sales_agent import SalesAgent
from app.ai.agents.inventory_agent import InventoryAgent
from app.ai.agents.accounting_agent import AccountingAgent
from app.ai.agents.manager_agent import ManagerAgent
from app.ai.tools.reporting_tools import ReportingTools
from app.ai.memory.conversation import ConversationMemory
from app.ai.rag.retriever import ERPContextRetriever
from app.core.redis import get_redis
from app.services.cache_service import CacheService


class AIService:
    """Orchestrates AI agents, memory, RAG, and predictions."""

    def __init__(self, db: Session):
        self.db = db
        self.cache = CacheService(get_redis())
        self.agents = {
            "sales": SalesAgent(db),
            "inventory": InventoryAgent(db),
            "accounting": AccountingAgent(db),
            "manager": ManagerAgent(db),
        }
        self.reporting = ReportingTools(db)
        self.retriever = ERPContextRetriever(db)

    def get_agent(self, agent_type: str):
        return self.agents.get(agent_type)

    def execute_tool(self, agent_type: str, tool_name: str, params: dict) -> dict:
        agent = self.get_agent(agent_type)
        if not agent:
            return {"error": f"Unknown agent: {agent_type}"}
        return agent.execute_tool(tool_name, params)

    def classify_and_route(self, query: str) -> dict:
        manager = self.agents["manager"]
        return manager.execute_query(query)

    # --- PREDICTIONS ---

    def demand_forecast(self, product_id: int, days_back: int = 30) -> dict:
        return self.reporting.demand_forecast(product_id, days_back)

    def low_stock_prediction(self, days_ahead: int = 7) -> dict:
        return self.reporting.low_stock_prediction(days_ahead)

    def best_selling_prediction(self, days_back: int = 30) -> dict:
        return self.reporting.best_selling_prediction(days_back)

    def customer_behavior(self, customer_id: int) -> dict:
        return self.reporting.customer_behavior_analysis(customer_id)

    def profit_analysis(self, start_date: str, end_date: str) -> dict:
        return self.reporting.profit_analysis(start_date, end_date)

    # --- RAG ---

    def search_context(self, query: str) -> dict:
        return {
            "products": self.retriever.search_products(query),
            "customers": self.retriever.search_customers(query),
            "suppliers": self.retriever.search_suppliers(query),
        }

    # --- MEMORY ---

    def get_memory(self, session_id: str) -> ConversationMemory:
        return ConversationMemory(session_id)

    def get_conversation(self, session_id: str) -> list:
        return ConversationMemory(session_id).get_history()

    def clear_conversation(self, session_id: str):
        ConversationMemory(session_id).clear()
