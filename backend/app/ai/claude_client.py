import json
from sqlalchemy.orm import Session
from app.ai.agents.manager_agent import ManagerAgent
from typing import AsyncGenerator
import logging

logger = logging.getLogger(__name__)


class ClaudeClient:
    """Claude AI client for the ERP assistant.
    Delegates all work to the Manager Agent, which orchestrates sub-agents.
    """

    def __init__(self, db: Session):
        self.db = db
        self.manager = ManagerAgent(db)

    def chat(self, session_id: str, user_message: str) -> str:
        """Process a chat message through the Manager Agent delegation system."""
        return self.manager.chat(session_id, user_message)

    async def chat_stream(self, session_id: str, user_message: str) -> AsyncGenerator[str, None]:
        """Streaming chat — delegates to Manager Agent, streams the final response.
        Tool calls happen synchronously within the Manager, only the final
        text response is streamed back to the client.
        """
        import anthropic
        from app.config import settings
        from app.ai.memory.conversation import ConversationMemory
        from app.ai.prompts.system_prompts import MANAGER_AGENT_PROMPT

        memory = ConversationMemory(session_id)
        memory.add_user_message(user_message)
        history = memory.get_context_window(max_messages=20)

        messages = []
        for msg in history:
            if msg["role"] in ("user", "assistant"):
                messages.append({"role": msg["role"], "content": msg["content"]})

        client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        model = settings.ai_model
        tools = self.manager.get_tools()

        response = client.messages.create(
            model=model,
            max_tokens=4096,
            system=MANAGER_AGENT_PROMPT,
            tools=tools,
            messages=messages,
        )

        # Handle tool use loop (non-streaming for tool calls)
        while response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    yield json.dumps({"type": "tool_call", "tool": block.name}) + "\n"
                    result = self.manager.execute_tool(block.name, block.input)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result,
                    })

            messages.append({"role": "assistant", "content": response.content})
            messages.append({"role": "user", "content": tool_results})

            response = client.messages.create(
                model=model,
                max_tokens=4096,
                system=MANAGER_AGENT_PROMPT,
                tools=tools,
                messages=messages,
            )

        # Stream final text response
        if response.stop_reason == "end_turn":
            # Re-do the final call as streaming
            full_text = ""
            with client.messages.stream(
                model=model,
                max_tokens=4096,
                system=MANAGER_AGENT_PROMPT,
                tools=tools,
                messages=messages,
            ) as stream:
                for text in stream.text_stream:
                    full_text += text
                    yield json.dumps({"type": "token", "text": text}) + "\n"

            if not full_text:
                for block in response.content:
                    if hasattr(block, "text"):
                        full_text += block.text
                        yield json.dumps({"type": "token", "text": block.text}) + "\n"

            memory.add_assistant_message(full_text)
            yield json.dumps({"type": "done", "full_text": full_text}) + "\n"
