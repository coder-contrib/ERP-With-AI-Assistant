import json
from sqlalchemy.orm import Session
from app.ai.agents.manager_agent import ManagerAgent, ALL_TOOL_SCHEMAS
from typing import AsyncGenerator
import logging

logger = logging.getLogger(__name__)


class ClaudeClient:
    """Entry point for the ERP AI assistant.
    Thin wrapper: routes messages to the Manager Agent.
    """

    def __init__(self, db: Session, user_role: str = "ai_agent"):
        self.db = db
        self.user_role = user_role
        self.manager = ManagerAgent(db, user_role=user_role, channel="chat")

    def chat(self, session_id: str, user_message: str) -> str:
        return self.manager.chat(session_id, user_message)

    async def chat_stream(self, session_id: str, user_message: str) -> AsyncGenerator[str, None]:
        """Streaming version. Tool calls execute synchronously,
        the final text response is yielded to the client.
        """
        import anthropic
        from app.config import settings
        from app.ai.memory.conversation import ConversationMemory
        from app.ai.prompts.system_prompts import MANAGER_AGENT_PROMPT
        from app.ai.executor import ToolExecutor

        memory = ConversationMemory(session_id)
        memory.add_user_message(user_message)
        history = memory.get_context_window(max_messages=20)

        messages = []
        for msg in history:
            if msg["role"] in ("user", "assistant"):
                messages.append({"role": msg["role"], "content": msg["content"]})

        client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        executor = ToolExecutor(self.db, session_id=session_id, user_role=self.user_role, channel="chat_stream")

        response = client.messages.create(
            model=settings.ai_model,
            max_tokens=4096,
            system=MANAGER_AGENT_PROMPT,
            tools=ALL_TOOL_SCHEMAS,
            messages=messages,
        )

        # Tool execution loop (non-streaming)
        while response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    yield json.dumps({"type": "tool_call", "tool": block.name}) + "\n"
                    result = executor.execute(block.name, block.input)
                    try:
                        memory.add_tool_result(block.name, json.loads(result))
                    except (json.JSONDecodeError, TypeError):
                        pass
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result,
                    })

            messages.append({"role": "assistant", "content": response.content})
            messages.append({"role": "user", "content": tool_results})

            response = client.messages.create(
                model=settings.ai_model,
                max_tokens=4096,
                system=MANAGER_AGENT_PROMPT,
                tools=ALL_TOOL_SCHEMAS,
                messages=messages,
            )

        # Yield final text directly from response (no redundant second API call)
        full_text = ""
        for block in response.content:
            if hasattr(block, "text"):
                full_text += block.text
                yield json.dumps({"type": "token", "text": block.text}) + "\n"

        memory.add_assistant_message(full_text)
        yield json.dumps({"type": "done", "full_text": full_text}) + "\n"
