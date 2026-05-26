import anthropic
import json
import logging
from typing import AsyncGenerator
from app.config import settings
from app.ai.memory.conversation import ConversationMemory
from app.ai.claude_client import ClaudeClient
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

VOICE_SYSTEM_PROMPT = """You are an intelligent ERP voice assistant for a ceramic showroom business.
You help the business owner manage sales, inventory, finances, and customers.

CRITICAL VOICE RULES:
- Respond in the SAME LANGUAGE the user speaks
- If user speaks Egyptian Arabic dialect, respond naturally in Egyptian dialect
- If user speaks formal Arabic, respond in formal Arabic
- If user speaks English, respond in English
- If user mixes languages (Franco-Arabic), respond in Arabic
- Keep responses SHORT and conversational (2-3 sentences max for voice)
- Use natural spoken language, not formal written style
- Avoid technical jargon - speak like a helpful business partner
- Numbers should be spoken naturally ("خمسة وعشرين ألف" not "25,000")
- Use Egyptian currency naturally ("جنيه" not "EGP")

VOICE RESPONSE STYLE:
- Be concise - the user is listening, not reading
- Lead with the answer, then details if needed
- Use conversational filler when appropriate ("تمام", "أهو", "يعني")
- Sound confident and knowledgeable
- For bad news, be empathetic but direct

EXAMPLES:
- User: "كام في الخزنة؟" → "في الخزنة دلوقتي تلاتين ألف وخمسمية جنيه"
- User: "المبيعات عاملة ايه؟" → "النهارده باعنا بخمستاشر ألف جنيه في ست فواتير، أحسن من امبارح"
- User: "العميل أحمد مديون بكام؟" → "أحمد عليه اتناشر ألف جنيه من تلات فواتير مش مدفوعين"

You have access to ERP tools to query real business data. Always use tools to get accurate information.
"""


class VoiceOrchestrator:
    """Orchestrates voice interactions: transcription → Claude reasoning → TTS."""

    def __init__(self, db: Session):
        self.db = db
        self.claude_client = ClaudeClient(db)
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self.model = settings.ai_model

    def process_voice_message(self, session_id: str, transcribed_text: str) -> dict:
        """Process transcribed voice input through Claude with tools."""
        memory = ConversationMemory(session_id)
        memory.add_user_message(transcribed_text)
        history = memory.get_context_window(max_messages=20)

        messages = []
        for msg in history:
            if msg["role"] in ("user", "assistant"):
                messages.append({"role": msg["role"], "content": msg["content"]})

        tools_used = []
        response = self.client.messages.create(
            model=self.model,
            max_tokens=1024,
            system=VOICE_SYSTEM_PROMPT,
            tools=self.claude_client.get_tools(),
            messages=messages,
        )

        while response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    tools_used.append(block.name)
                    result = self.claude_client.execute_tool(block.name, block.input)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result,
                    })

            messages.append({"role": "assistant", "content": response.content})
            messages.append({"role": "user", "content": tool_results})

            response = self.client.messages.create(
                model=self.model,
                max_tokens=1024,
                system=VOICE_SYSTEM_PROMPT,
                tools=self.claude_client.get_tools(),
                messages=messages,
            )

        assistant_text = ""
        for block in response.content:
            if hasattr(block, "text"):
                assistant_text += block.text

        memory.add_assistant_message(assistant_text)

        return {
            "text": assistant_text,
            "tools_used": tools_used,
            "session_id": session_id,
        }

    async def process_voice_stream(self, session_id: str, transcribed_text: str) -> AsyncGenerator[dict, None]:
        """Stream voice processing events for realtime UI updates."""
        memory = ConversationMemory(session_id)
        memory.add_user_message(transcribed_text)
        history = memory.get_context_window(max_messages=20)

        messages = []
        for msg in history:
            if msg["role"] in ("user", "assistant"):
                messages.append({"role": msg["role"], "content": msg["content"]})

        tools_used = []

        yield {"type": "transcription_complete", "data": {"text": transcribed_text}}

        response = self.client.messages.create(
            model=self.model,
            max_tokens=1024,
            system=VOICE_SYSTEM_PROMPT,
            tools=self.claude_client.get_tools(),
            messages=messages,
        )

        while response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    tools_used.append(block.name)
                    yield {"type": "tool_call_started", "data": {"tool": block.name}}
                    result = self.claude_client.execute_tool(block.name, block.input)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result,
                    })
                    yield {"type": "tool_call_finished", "data": {"tool": block.name}}

            messages.append({"role": "assistant", "content": response.content})
            messages.append({"role": "user", "content": tool_results})

            response = self.client.messages.create(
                model=self.model,
                max_tokens=1024,
                system=VOICE_SYSTEM_PROMPT,
                tools=self.claude_client.get_tools(),
                messages=messages,
            )

        assistant_text = ""
        for block in response.content:
            if hasattr(block, "text"):
                assistant_text += block.text

        memory.add_assistant_message(assistant_text)

        yield {"type": "ai_response_complete", "data": {"text": assistant_text, "tools_used": tools_used}}
        yield {"type": "ai_speaking", "data": {"text": assistant_text}}
