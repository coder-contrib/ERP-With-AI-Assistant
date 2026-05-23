from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.database import get_db
from app.core.deps import get_current_user
from app.models.users import User
from app.services.ai_service import AIService
from app.ai.claude_client import ClaudeClient

router = APIRouter()


class ToolRequest(BaseModel):
    agent: str
    tool: str
    params: dict = {}


class ChatRequest(BaseModel):
    session_id: str
    message: str


# --- CHAT (Claude Sonnet) ---

@router.post("/chat")
def ai_chat(data: ChatRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    client = ClaudeClient(db)
    response = client.chat(data.session_id, data.message)
    return {"response": response, "session_id": data.session_id}


@router.post("/chat/stream")
def ai_chat_stream(data: ChatRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    client = ClaudeClient(db)
    return StreamingResponse(
        client.chat_stream(data.session_id, data.message),
        media_type="text/event-stream",
    )


# --- TOOL EXECUTION ---

@router.post("/tool")
def execute_ai_tool(data: ToolRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.execute_tool(data.agent, data.tool, data.params)


@router.post("/query")
def ai_query(data: ChatRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    routing = service.classify_and_route(data.message)
    context = service.search_context(data.message)
    return {"routing": routing, "context": context, "session_id": data.session_id}


# --- AGENTS ---

@router.get("/agents")
def list_agents(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return {
        agent_type: {"tools": agent.get_tools_schema(), "description": agent.system_prompt.split("\n")[0]}
        for agent_type, agent in service.agents.items()
    }


# --- PREDICTIONS ---

@router.get("/predict/demand/{product_id}")
def predict_demand(product_id: int, days_back: int = 30, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.demand_forecast(product_id, days_back)


@router.get("/predict/low-stock")
def predict_low_stock(days_ahead: int = 7, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.low_stock_prediction(days_ahead)


@router.get("/predict/trending")
def predict_trending(days_back: int = 30, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.best_selling_prediction(days_back)


@router.get("/predict/customer/{customer_id}")
def predict_customer(customer_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.customer_behavior(customer_id)


@router.get("/analyze/profit")
def analyze_profit(start_date: str, end_date: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.profit_analysis(start_date, end_date)


# --- SEARCH / RAG ---

@router.get("/search")
def ai_search(query: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.search_context(query)


# --- CONVERSATION MEMORY ---

@router.get("/conversation/{session_id}")
def get_conversation(session_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return {"messages": service.get_conversation(session_id)}


@router.delete("/conversation/{session_id}")
def clear_conversation(session_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    service.clear_conversation(session_id)
    return {"detail": "Conversation cleared"}
