import anthropic
import json
from sqlalchemy.orm import Session
from app.config import settings
from app.ai.executor import ToolExecutor
from app.ai.memory.conversation import ConversationMemory
from app.ai.prompts.system_prompts import MANAGER_AGENT_PROMPT
from app.ai.tools.tool_schemas import TOOL_SCHEMAS
import logging

logger = logging.getLogger(__name__)


class ManagerAgent:
    """Planner / Router ONLY.
    Uses Claude to understand user intent and decide which tools to call.
    Does NOT execute anything itself — passes decisions to the ToolExecutor.
    """

    def __init__(self, db: Session):
        self.db = db
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self.model = settings.ai_model
        self.executor = ToolExecutor(db)

    def chat(self, session_id: str, user_message: str) -> str:
        memory = ConversationMemory(session_id)
        memory.add_user_message(user_message)
        history = memory.get_context_window(max_messages=20)

        messages = []
        for msg in history:
            if msg["role"] in ("user", "assistant"):
                messages.append({"role": msg["role"], "content": msg["content"]})

        # Manager plans: Claude decides which tools to call
        response = self.client.messages.create(
            model=self.model,
            max_tokens=4096,
            system=MANAGER_AGENT_PROMPT,
            tools=TOOL_SCHEMAS,
            messages=messages,
        )

        # Planning loop: Manager plans, Executor executes
        while response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    logger.info(f"Manager planned: {block.name}")
                    # Execution layer handles it — no LLM here
                    result = self.executor.execute(block.name, block.input)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result,
                    })
                    memory.add_tool_result(block.name, json.loads(result))

            messages.append({"role": "assistant", "content": response.content})
            messages.append({"role": "user", "content": tool_results})

            # Manager sees results and plans next step (or responds)
            response = self.client.messages.create(
                model=self.model,
                max_tokens=4096,
                system=MANAGER_AGENT_PROMPT,
                tools=TOOL_SCHEMAS,
                messages=messages,
            )

        # Extract final text
        assistant_text = ""
        for block in response.content:
            if hasattr(block, "text"):
                assistant_text += block.text

        memory.add_assistant_message(assistant_text)
        return assistant_text
