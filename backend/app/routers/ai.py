from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.database import get_db
from app.core.deps import get_current_user
from app.models.users import User
from app.services.ai_service import AIService

router = APIRouter()


class ToolRequest(BaseModel):
    agent: str
    tool: str
    params: dict = {}


class ChatRequest(BaseModel):
    session_id: str
    message: str


@router.post("/tool")
def execute_ai_tool(data: ToolRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    result = service.execute_tool(data.agent, data.tool, data.params)
    return result


@router.get("/agents")
def list_agents(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return {
        agent_type: {
            "tools": agent.get_tools_schema(),
            "description": agent.system_prompt.split("\n")[0],
        }
        for agent_type, agent in service.agents.items()
    }


@router.get("/conversation/{session_id}")
def get_conversation(session_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return {"messages": service.get_conversation(session_id)}


@router.delete("/conversation/{session_id}")
def clear_conversation(session_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    service.clear_conversation(session_id)
    return {"detail": "Conversation cleared"}
