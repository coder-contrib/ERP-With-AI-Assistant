import anthropic
import asyncio
import json
from sqlalchemy.orm import Session
from app.config import settings
from app.ai.executor import ToolExecutor
from app.ai.memory.conversation import ConversationMemory
from app.ai.memory.vector_memory import VectorMemory
from app.ai.prompts.system_prompts import MANAGER_AGENT_PROMPT
from app.ai.tools.tool_schemas import TOOL_SCHEMAS
import logging

logger = logging.getLogger(__name__)

# Add confirmation tool to schemas
CONFIRMATION_TOOL = {
    "name": "confirm_transaction",
    "description": "تأكيد عملية معلقة بعد موافقة المستخدم. استخدم هذا عندما يقول المستخدم 'أكد' أو 'تأكيد' أو 'نعم نفذ'.",
    "input_schema": {
        "type": "object",
        "properties": {
            "confirmation_id": {
                "type": "string",
                "description": "الكود المرجعي للعملية المعلقة",
            }
        },
        "required": ["confirmation_id"],
    },
}

ALL_TOOL_SCHEMAS = TOOL_SCHEMAS + [CONFIRMATION_TOOL]


class ManagerAgent:
    """Planner / Router ONLY.
    Uses Claude to understand user intent and decide which tools to call.
    Does NOT execute anything itself — passes decisions to the ToolExecutor.
    """

    def __init__(self, db: Session, user_role: str = "ai_agent"):
        self.db = db
        self.user_role = user_role
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self.model = settings.ai_model
        self.vector_memory = VectorMemory()

    def chat(self, session_id: str, user_message: str, on_tool_call=None) -> str:
        memory = ConversationMemory(session_id)
        memory.add_user_message(user_message)
        history = memory.get_context_window(max_messages=20)

        # Create executor scoped to this session + user role
        executor = ToolExecutor(self.db, session_id=session_id, user_role=self.user_role)

        # Retrieve long-term memory context
        long_term_context = self._get_long_term_context(user_message)

        # Build system prompt with memory context
        system_prompt = MANAGER_AGENT_PROMPT
        if long_term_context:
            system_prompt += f"\n\n{long_term_context}"

        messages = []
        for msg in history:
            if msg["role"] in ("user", "assistant"):
                messages.append({"role": msg["role"], "content": msg["content"]})

        response = self.client.messages.create(
            model=self.model,
            max_tokens=4096,
            system=system_prompt,
            tools=ALL_TOOL_SCHEMAS,
            messages=messages,
        )

        # Planning loop: Manager plans, Executor executes
        while response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    logger.info(f"Manager planned: {block.name} (role={self.user_role})")
                    if on_tool_call:
                        on_tool_call(block.name, "started")
                    result = executor.execute(block.name, block.input)
                    if on_tool_call:
                        on_tool_call(block.name, "finished")
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result,
                    })
                    memory.add_tool_result(block.name, json.loads(result))

            messages.append({"role": "assistant", "content": response.content})
            messages.append({"role": "user", "content": tool_results})

            response = self.client.messages.create(
                model=self.model,
                max_tokens=4096,
                system=system_prompt,
                tools=ALL_TOOL_SCHEMAS,
                messages=messages,
            )

        # Extract final text
        assistant_text = ""
        for block in response.content:
            if hasattr(block, "text"):
                assistant_text += block.text

        memory.add_assistant_message(assistant_text)
        return assistant_text

    def _get_long_term_context(self, query: str) -> str:
        """Retrieve relevant long-term memory for the current query."""
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                import concurrent.futures
                with concurrent.futures.ThreadPoolExecutor() as pool:
                    future = pool.submit(asyncio.run, self.vector_memory.get_context_for_query(query))
                    return future.result(timeout=5)
            else:
                return loop.run_until_complete(self.vector_memory.get_context_for_query(query))
        except Exception as e:
            logger.warning(f"Long-term memory retrieval failed (non-critical): {e}")
            return ""
