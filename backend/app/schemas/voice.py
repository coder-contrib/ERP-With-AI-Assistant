from pydantic import BaseModel
from typing import Optional
from enum import Enum


class VoiceLanguage(str, Enum):
    ARABIC = "ar"
    EGYPTIAN_ARABIC = "ar-EG"
    ENGLISH = "en"
    AUTO = "auto"


class VoiceState(str, Enum):
    IDLE = "idle"
    LISTENING = "listening"
    PROCESSING = "processing"
    TOOL_EXECUTION = "tool_execution"
    SPEAKING = "speaking"


class TranscribeRequest(BaseModel):
    language: VoiceLanguage = VoiceLanguage.AUTO


class TranscribeResponse(BaseModel):
    text: str
    language_detected: str
    confidence: float
    duration_seconds: float


class VoiceRespondRequest(BaseModel):
    session_id: str
    text: Optional[str] = None
    language: VoiceLanguage = VoiceLanguage.AUTO


class VoiceRespondResponse(BaseModel):
    transcript: str
    audio_url: Optional[str] = None
    tools_used: list[str] = []
    language: str
    session_id: str


class VoiceFullRequest(BaseModel):
    session_id: str
    language: VoiceLanguage = VoiceLanguage.AUTO


class VoiceEvent(BaseModel):
    type: str
    data: dict = {}


class VoiceStreamEvent(str, Enum):
    RECORDING_STARTED = "recording_started"
    TRANSCRIPTION_PARTIAL = "transcription_partial"
    TRANSCRIPTION_COMPLETE = "transcription_complete"
    TOOL_CALL_STARTED = "tool_call_started"
    TOOL_CALL_FINISHED = "tool_call_finished"
    AI_RESPONSE_PARTIAL = "ai_response_partial"
    AI_SPEAKING = "ai_speaking"
    AI_FINISHED = "ai_finished"
    ERROR = "error"
