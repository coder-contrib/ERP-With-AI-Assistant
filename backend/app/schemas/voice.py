from pydantic import BaseModel
from enum import Enum
from typing import Optional


class VoiceLanguage(str, Enum):
    auto = "auto"
    arabic = "ar"
    english = "en"


class TranscribeResponse(BaseModel):
    text: str
    language_detected: str
    confidence: float
    duration_seconds: float


class VoiceRespondRequest(BaseModel):
    text: Optional[str] = None
    session_id: str = "voice-default"
    language: str = "auto"


class VoiceRespondResponse(BaseModel):
    transcript: str
    tools_used: list[str] = []
    language: str = "ar"
    session_id: str = ""
