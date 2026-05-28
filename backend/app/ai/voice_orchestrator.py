from sqlalchemy.orm import Session
from app.ai.agents.manager_agent import ManagerAgent
import logging

logger = logging.getLogger(__name__)


class VoiceOrchestrator:
    """Bridges voice input to the AI Manager Agent.
    Takes transcribed text, sends to the Manager, returns response + tools used.
    """

    def __init__(self, db: Session, user_role: str = "ai_agent"):
        self.db = db
        self.user_role = user_role
        self.manager = ManagerAgent(db, user_role=user_role)

    def process_voice_message(self, session_id: str, text: str, priority: str = "normal", on_tool_call=None) -> dict:
        """Process a voice message through the Manager Agent.

        Args:
            session_id: Conversation session ID
            text: Transcribed user speech
            priority: "high" if this follows a barge-in (user interrupted AI),
                      "normal" otherwise.
            on_tool_call: Optional callback(tool_name, status) for real-time tool events.

        Returns: {text: str, tools_used: list[str]}
        """
        if not text or not text.strip():
            return {"text": "لم أسمع شيء. جرب تاني.", "tools_used": []}

        try:
            if priority == "high":
                prefixed_text = f"[المستخدم قاطعك - تجاهل ردك السابق وركز على الطلب الجديد] {text}"
            else:
                prefixed_text = text

            response = self.manager.chat(session_id, prefixed_text, on_tool_call=on_tool_call)
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
                if msg.get("role") == "tool":
                    tool_name = msg.get("tool_name", "")
                    if tool_name:
                        tools.append(tool_name)
                elif msg.get("role") == "user" and not msg.get("is_tool_result"):
                    break
            return tools
        except Exception:
            return []
