from app.core.redis import get_redis
from app.services.cache_service import CacheService
from datetime import datetime


class ConversationMemory:
    """Manages AI conversation memory in Redis.
    Stores per-session conversation history for context.
    """

    def __init__(self, session_id: str):
        self.session_id = session_id
        self.cache = CacheService(get_redis())

    def get_history(self) -> list[dict]:
        return self.cache.get_ai_conversation(self.session_id) or []

    def add_user_message(self, content: str):
        self.cache.append_ai_message(self.session_id, {
            "role": "user",
            "content": content,
            "timestamp": datetime.utcnow().isoformat(),
        })

    def add_assistant_message(self, content: str, tool_calls: list | None = None):
        msg = {
            "role": "assistant",
            "content": content,
            "timestamp": datetime.utcnow().isoformat(),
        }
        if tool_calls:
            msg["tool_calls"] = tool_calls
        self.cache.append_ai_message(self.session_id, msg)

    def add_tool_result(self, tool_name: str, result: dict):
        self.cache.append_ai_message(self.session_id, {
            "role": "tool",
            "tool_name": tool_name,
            "content": result,
            "timestamp": datetime.utcnow().isoformat(),
        })

    def clear(self):
        self.cache.clear_ai_conversation(self.session_id)

    def get_context_window(self, max_messages: int = 20) -> list[dict]:
        history = self.get_history()
        return history[-max_messages:]
