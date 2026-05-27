from sqlalchemy.orm import Session
from app.ai.agents.manager_agent import ManagerAgent
import logging

logger = logging.getLogger(__name__)


class VoiceOrchestrator:
    """Bridges voice input to the AI Manager Agent.
    Takes transcribed text, sends to the Manager, returns response + tools used.
    """

    def __init__(self, db: Session):
        self.db = db
        self.manager = ManagerAgent(db)

    def process_voice_message(self, session_id: str, text: str) -> dict:
        """Process a voice message through the Manager Agent.
        Returns: {text: str, tools_used: list[str]}
        """
        if not text or not text.strip():
            return {"text": "لم أسمع شيء. جرب تاني.", "tools_used": []}

        try:
            # Use the Manager Agent (same as text chat)
            response = self.manager.chat(session_id, text)
            return {
                "text": response,
                "tools_used": self._extract_tools_used(session_id),
            }
        except Exception as e:
            logger.error(f"Voice orchestrator error: {e}")
            return {
                "text": "حصل مشكلة. جرب تاني.",
                "tools_used": [],
            }

    def _extract_tools_used(self, session_id: str) -> list[str]:
        """Extract which tools were used from the conversation memory."""
        try:
            from app.ai.memory.conversation import ConversationMemory
            memory = ConversationMemory(session_id)
            history = memory.get_context_window(max_messages=10)
            tools = []
            for msg in reversed(history):
                if msg.get("role") == "tool_result":
                    tool_name = msg.get("tool_name", "")
                    if tool_name:
                        tools.append(tool_name)
                elif msg.get("role") == "user" and not msg.get("is_tool_result"):
                    break
            return tools
        except Exception:
            return []
