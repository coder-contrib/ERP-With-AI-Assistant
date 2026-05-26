import httpx
import io
import logging
from typing import AsyncGenerator
from app.config import settings

logger = logging.getLogger(__name__)


class VoiceService:
    """Handles Speech-to-Text (Whisper) and Text-to-Speech (ElevenLabs)."""

    def __init__(self):
        self.whisper_api_key = settings.openai_api_key
        self.elevenlabs_api_key = settings.elevenlabs_api_key
        self.elevenlabs_voice_id = settings.elevenlabs_voice_id

    async def transcribe(self, audio_data: bytes, language: str = "auto") -> dict:
        """Transcribe audio using OpenAI Whisper API with Arabic/Egyptian support."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            files = {"file": ("audio.wav", io.BytesIO(audio_data), "audio/wav")}
            data = {
                "model": "whisper-1",
                "response_format": "verbose_json",
            }
            if language and language != "auto":
                lang_map = {"ar": "ar", "ar-EG": "ar", "en": "en"}
                data["language"] = lang_map.get(language, "ar")

            response = await client.post(
                "https://api.openai.com/v1/audio/transcriptions",
                headers={"Authorization": f"Bearer {self.whisper_api_key}"},
                files=files,
                data=data,
            )
            response.raise_for_status()
            result = response.json()

            return {
                "text": result.get("text", ""),
                "language_detected": result.get("language", "ar"),
                "confidence": self._avg_confidence(result.get("segments", [])),
                "duration_seconds": result.get("duration", 0),
            }

    async def text_to_speech(self, text: str) -> bytes:
        """Convert text to speech using ElevenLabs API."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"https://api.elevenlabs.io/v1/text-to-speech/{self.elevenlabs_voice_id}",
                headers={
                    "xi-api-key": self.elevenlabs_api_key,
                    "Content-Type": "application/json",
                    "Accept": "audio/mpeg",
                },
                json={
                    "text": text,
                    "model_id": "eleven_multilingual_v2",
                    "voice_settings": {
                        "stability": 0.5,
                        "similarity_boost": 0.8,
                        "style": 0.2,
                        "use_speaker_boost": True,
                    },
                },
            )
            response.raise_for_status()
            return response.content

    async def text_to_speech_stream(self, text: str) -> AsyncGenerator[bytes, None]:
        """Stream TTS audio chunks for low-latency playback."""
        async with httpx.AsyncClient(timeout=60.0) as client:
            async with client.stream(
                "POST",
                f"https://api.elevenlabs.io/v1/text-to-speech/{self.elevenlabs_voice_id}/stream",
                headers={
                    "xi-api-key": self.elevenlabs_api_key,
                    "Content-Type": "application/json",
                    "Accept": "audio/mpeg",
                },
                json={
                    "text": text,
                    "model_id": "eleven_multilingual_v2",
                    "voice_settings": {
                        "stability": 0.5,
                        "similarity_boost": 0.8,
                        "style": 0.2,
                        "use_speaker_boost": True,
                    },
                    "optimize_streaming_latency": 3,
                },
            ) as response:
                response.raise_for_status()
                async for chunk in response.aiter_bytes(chunk_size=4096):
                    yield chunk

    def _avg_confidence(self, segments: list) -> float:
        if not segments:
            return 0.0
        confidences = [s.get("avg_logprob", -1) for s in segments]
        avg_logprob = sum(confidences) / len(confidences)
        return min(max((avg_logprob + 1) / 1, 0), 1)
