import io
import httpx
import asyncio
import websockets
import json
from typing import AsyncGenerator
from app.config import settings
import logging

logger = logging.getLogger(__name__)


class VoiceService:
    """Handles Speech-to-Text (Whisper/Deepgram) and Text-to-Speech (Azure/ElevenLabs)."""

    def __init__(self):
        self.openai_api_key = settings.openai_api_key
        self.deepgram_api_key = settings.deepgram_api_key
        self.elevenlabs_api_key = settings.elevenlabs_api_key
        self.elevenlabs_voice_id = settings.elevenlabs_voice_id
        self.azure_speech_key = settings.azure_speech_key
        self.azure_speech_region = settings.azure_speech_region
        self.azure_tts_voice = settings.azure_tts_voice

    async def transcribe(self, audio_data: bytes, language: str = "auto") -> dict:
        """Transcribe audio using OpenAI Whisper API (batch mode)."""
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

    async def create_streaming_transcription(self, language: str = "ar"):
        """Create a Deepgram streaming transcription session."""
        if self.deepgram_api_key:
            return DeepgramStreamer(self.deepgram_api_key, language)
        else:
            return WhisperBufferedStreamer(self.openai_api_key, language)

    async def text_to_speech(self, text: str) -> bytes:
        """Convert text to speech. Uses Azure (Egyptian Arabic) if configured, else ElevenLabs."""
        if self.azure_speech_key:
            return await self._azure_tts(text)
        elif self.elevenlabs_api_key:
            return await self._elevenlabs_tts(text)
        return b""

    async def text_to_speech_stream(self, text: str) -> AsyncGenerator[bytes, None]:
        """Stream TTS audio for low-latency playback."""
        if self.azure_speech_key:
            audio = await self._azure_tts(text)
            if audio:
                chunk_size = 4096
                for i in range(0, len(audio), chunk_size):
                    yield audio[i:i + chunk_size]
        elif self.elevenlabs_api_key:
            async for chunk in self._elevenlabs_tts_stream(text):
                yield chunk

    # === Azure TTS (Egyptian Arabic) ===

    async def _azure_tts(self, text: str) -> bytes:
        """Convert text to speech using Azure Cognitive Services (ar-EG-ShakirNeural)."""
        token_url = f"https://{self.azure_speech_region}.api.cognitive.microsoft.com/sts/v1.0/issueToken"
        tts_url = f"https://{self.azure_speech_region}.tts.speech.microsoft.com/cognitiveservices/v1"

        async with httpx.AsyncClient(timeout=30.0) as client:
            # Get access token
            token_resp = await client.post(
                token_url,
                headers={
                    "Ocp-Apim-Subscription-Key": self.azure_speech_key,
                    "Content-Length": "0",
                },
            )
            if token_resp.status_code != 200:
                logger.error(f"Azure token error: {token_resp.status_code}")
                return b""

            access_token = token_resp.text

            # Build SSML for natural Egyptian Arabic speech
            ssml = (
                '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="ar-EG">'
                f'<voice name="{self.azure_tts_voice}">'
                f'<prosody rate="0%">{_escape_xml(text)}</prosody>'
                '</voice></speak>'
            )

            # Request audio
            response = await client.post(
                tts_url,
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/ssml+xml",
                    "X-Microsoft-OutputFormat": "audio-16khz-128kbitrate-mono-mp3",
                },
                content=ssml.encode("utf-8"),
            )

            if response.status_code != 200:
                logger.error(f"Azure TTS error: {response.status_code} {response.text[:200]}")
                return b""

            return response.content

    # === ElevenLabs TTS (fallback) ===

    async def _elevenlabs_tts(self, text: str) -> bytes:
        """Convert text to speech using ElevenLabs API."""
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

    async def _elevenlabs_tts_stream(self, text: str) -> AsyncGenerator[bytes, None]:
        """Stream TTS audio from ElevenLabs."""
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


def _escape_xml(text: str) -> str:
    """Escape special XML characters for SSML."""
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


class DeepgramStreamer:
    """Real-time streaming transcription using Deepgram WebSocket API.
    Supports Arabic with interim (partial) results.
    """

    def __init__(self, api_key: str, language: str = "ar"):
        self.api_key = api_key
        self.language = language
        self._ws = None
        self._results_queue = asyncio.Queue()
        self._task = None

    async def connect(self):
        """Open the Deepgram streaming WebSocket."""
        url = (
            f"wss://api.deepgram.com/v1/listen"
            f"?model=nova-2"
            f"&language={self.language}"
            f"&smart_format=true"
            f"&interim_results=true"
            f"&utterance_end_ms=1500"
            f"&vad_events=true"
            f"&encoding=linear16"
            f"&sample_rate=16000"
            f"&channels=1"
        )
        self._ws = await websockets.connect(
            url,
            extra_headers={"Authorization": f"Token {self.api_key}"},
        )
        self._task = asyncio.create_task(self._receive_loop())

    async def _receive_loop(self):
        """Listen for transcription results from Deepgram."""
        try:
            async for message in self._ws:
                data = json.loads(message)
                msg_type = data.get("type", "")

                if msg_type == "Results":
                    channel = data.get("channel", {})
                    alternatives = channel.get("alternatives", [{}])
                    if alternatives:
                        transcript = alternatives[0].get("transcript", "")
                        is_final = data.get("is_final", False)
                        if transcript.strip():
                            await self._results_queue.put({
                                "text": transcript,
                                "is_final": is_final,
                                "confidence": alternatives[0].get("confidence", 0),
                            })

                elif msg_type == "UtteranceEnd":
                    await self._results_queue.put({
                        "type": "utterance_end",
                    })

        except websockets.exceptions.ConnectionClosed:
            pass
        except Exception as e:
            logger.error(f"Deepgram receive error: {e}")

    async def send_audio(self, audio_chunk: bytes):
        """Send raw audio bytes (PCM 16-bit, 16kHz, mono) to Deepgram."""
        if self._ws:
            await self._ws.send(audio_chunk)

    async def get_result(self, timeout: float = 0.1):
        """Get next transcription result (partial or final). Returns None if no result ready."""
        try:
            return await asyncio.wait_for(self._results_queue.get(), timeout=timeout)
        except asyncio.TimeoutError:
            return None

    async def finish(self) -> str:
        """Signal end of audio and get any remaining transcription."""
        if self._ws:
            await self._ws.send(json.dumps({"type": "CloseStream"}))
            await asyncio.sleep(0.5)

        final_text = ""
        while not self._results_queue.empty():
            result = await self._results_queue.get()
            if result.get("is_final") and result.get("text"):
                final_text += result["text"] + " "
        return final_text.strip()

    async def close(self):
        """Close the WebSocket connection."""
        if self._task:
            self._task.cancel()
        if self._ws:
            await self._ws.close()


class WhisperBufferedStreamer:
    """Fallback: buffers audio chunks and uses Whisper API periodically."""

    def __init__(self, api_key: str, language: str = "ar"):
        self.api_key = api_key
        self.language = language
        self._buffer = bytearray()
        self._results_queue = asyncio.Queue()
        self._last_transcription = ""

    async def connect(self):
        pass

    async def send_audio(self, audio_chunk: bytes):
        """Buffer audio chunk. Transcribe when buffer reaches ~2 seconds of audio."""
        self._buffer.extend(audio_chunk)
        if len(self._buffer) >= 64000:
            await self._transcribe_buffer(is_final=False)

    async def _transcribe_buffer(self, is_final: bool = False):
        if not self._buffer or not self.api_key:
            return

        audio_data = bytes(self._buffer)
        if not is_final:
            self._buffer = self._buffer[-16000:]
        else:
            self._buffer.clear()

        async with httpx.AsyncClient(timeout=15.0) as client:
            files = {"file": ("audio.wav", io.BytesIO(audio_data), "audio/wav")}
            data = {"model": "whisper-1", "response_format": "json"}
            if self.language != "auto":
                data["language"] = self.language

            try:
                response = await client.post(
                    "https://api.openai.com/v1/audio/transcriptions",
                    headers={"Authorization": f"Bearer {self.api_key}"},
                    files=files,
                    data=data,
                )
                if response.status_code == 200:
                    text = response.json().get("text", "")
                    if text and text != self._last_transcription:
                        self._last_transcription = text
                        await self._results_queue.put({
                            "text": text,
                            "is_final": is_final,
                            "confidence": 0.9,
                        })
            except Exception as e:
                logger.error(f"Whisper streaming fallback error: {e}")

    async def get_result(self, timeout: float = 0.1):
        try:
            return await asyncio.wait_for(self._results_queue.get(), timeout=timeout)
        except asyncio.TimeoutError:
            return None

    async def finish(self) -> str:
        """Transcribe remaining buffer."""
        if self._buffer:
            await self._transcribe_buffer(is_final=True)
        final = ""
        while not self._results_queue.empty():
            result = await self._results_queue.get()
            if result.get("text"):
                final = result["text"]
        return final or self._last_transcription

    async def close(self):
        self._buffer.clear()
