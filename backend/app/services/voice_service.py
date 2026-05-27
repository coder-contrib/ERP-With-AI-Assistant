import io
import httpx
from typing import AsyncGenerator
from app.config import settings
import logging

logger = logging.getLogger(__name__)


class VoiceService:
    """Handles Speech-to-Text (Whisper) and Text-to-Speech (ElevenLabs)."""

    def __init__(self):
        self.openai_api_key = settings.openai_api_key
        self.elevenlabs_api_key = settings.elevenlabs_api_key
        self.elevenlabs_voice_id = settings.elevenlabs_voice_id

    async def transcribe(self, audio_data: bytes, language: str = "auto") -> dict:
        """Transcribe audio using OpenAI Whisper API. Supports Arabic natively."""
        if not self.openai_api_key:
            return {
                "text": "",
                "language_detected": "ar",
                "confidence": 0,
                "duration_seconds": 0,
                "error": "OPENAI_API_KEY not configured",
            }

        async with httpx.AsyncClient(timeout=30.0) as client:
            files = {"file": ("audio.wav", io.BytesIO(audio_data), "audio/wav")}
            data = {"model": "whisper-1", "response_format": "verbose_json"}
            if language != "auto":
                data["language"] = language

            response = await client.post(
                "https://api.openai.com/v1/audio/transcriptions",
                headers={"Authorization": f"Bearer {self.openai_api_key}"},
                files=files,
                data=data,
            )

            if response.status_code != 200:
                logger.error(f"Whisper API error: {response.status_code} {response.text}")
                return {
                    "text": "",
                    "language_detected": "ar",
                    "confidence": 0,
                    "duration_seconds": 0,
                    "error": f"Whisper API error: {response.status_code}",
                }

            result = response.json()
            return {
                "text": result.get("text", ""),
                "language_detected": result.get("language", "ar"),
                "confidence": 0.95,
                "duration_seconds": result.get("duration", 0),
            }

    async def text_to_speech(self, text: str) -> bytes:
        """Convert text to speech using ElevenLabs API."""
        if not self.elevenlabs_api_key:
            return b""

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"https://api.elevenlabs.io/v1/text-to-speech/{self.elevenlabs_voice_id}",
                headers={
                    "xi-api-key": self.elevenlabs_api_key,
                    "Content-Type": "application/json",
                },
                json={
                    "text": text,
                    "model_id": "eleven_multilingual_v2",
                    "voice_settings": {
                        "stability": 0.5,
                        "similarity_boost": 0.75,
                    },
                },
            )

            if response.status_code != 200:
                logger.error(f"ElevenLabs API error: {response.status_code}")
                return b""

            return response.content

    async def text_to_speech_stream(self, text: str) -> AsyncGenerator[bytes, None]:
        """Stream TTS audio for low-latency playback."""
        if not self.elevenlabs_api_key:
            return

        async with httpx.AsyncClient(timeout=30.0) as client:
            async with client.stream(
                "POST",
                f"https://api.elevenlabs.io/v1/text-to-speech/{self.elevenlabs_voice_id}/stream",
                headers={
                    "xi-api-key": self.elevenlabs_api_key,
                    "Content-Type": "application/json",
                },
                json={
                    "text": text,
                    "model_id": "eleven_multilingual_v2",
                    "voice_settings": {
                        "stability": 0.5,
                        "similarity_boost": 0.75,
                    },
                },
            ) as response:
                if response.status_code != 200:
                    return
                async for chunk in response.aiter_bytes(1024):
                    yield chunk
