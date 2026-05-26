import json
import logging
from fastapi import WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from app.ai.voice_orchestrator import VoiceOrchestrator
from app.services.voice_service import VoiceService
from app.schemas.voice import VoiceStreamEvent
import base64

logger = logging.getLogger(__name__)


class VoiceWebSocketManager:
    """Manages realtime voice WebSocket connections."""

    def __init__(self):
        self.active_connections: dict[str, WebSocket] = {}

    async def connect(self, session_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[session_id] = websocket

    def disconnect(self, session_id: str):
        self.active_connections.pop(session_id, None)

    async def send_event(self, session_id: str, event_type: str, data: dict = {}):
        ws = self.active_connections.get(session_id)
        if ws:
            await ws.send_json({"type": event_type, "data": data})


voice_ws_manager = VoiceWebSocketManager()


async def handle_voice_websocket(websocket: WebSocket, session_id: str, db: Session):
    """Handle a realtime voice WebSocket connection."""
    await voice_ws_manager.connect(session_id, websocket)
    voice_service = VoiceService()
    orchestrator = VoiceOrchestrator(db)

    try:
        while True:
            raw = await websocket.receive_text()
            message = json.loads(raw)
            msg_type = message.get("type")

            if msg_type == "audio":
                await websocket.send_json({"type": VoiceStreamEvent.RECORDING_STARTED, "data": {}})

                audio_b64 = message.get("data", "")
                audio_bytes = base64.b64decode(audio_b64)

                transcription = await voice_service.transcribe(audio_bytes)
                await websocket.send_json({
                    "type": VoiceStreamEvent.TRANSCRIPTION_COMPLETE,
                    "data": transcription,
                })

                async for event in orchestrator.process_voice_stream(session_id, transcription["text"]):
                    await websocket.send_json(event)

                response_text = ""
                async for event in orchestrator.process_voice_stream(session_id, transcription["text"]):
                    if event["type"] == "ai_response_complete":
                        response_text = event["data"]["text"]
                        break

                async for chunk in voice_service.text_to_speech_stream(response_text):
                    await websocket.send_bytes(chunk)

                await websocket.send_json({
                    "type": VoiceStreamEvent.AI_FINISHED,
                    "data": {"text": response_text},
                })

            elif msg_type == "text":
                text = message.get("data", {}).get("message", "")
                if not text:
                    continue

                async for event in orchestrator.process_voice_stream(session_id, text):
                    await websocket.send_json(event)

                result = orchestrator.process_voice_message(session_id, text)
                tts_text = result["text"]

                await websocket.send_json({"type": VoiceStreamEvent.AI_SPEAKING, "data": {"text": tts_text}})

                async for chunk in voice_service.text_to_speech_stream(tts_text):
                    await websocket.send_bytes(chunk)

                await websocket.send_json({"type": VoiceStreamEvent.AI_FINISHED, "data": {"text": tts_text}})

            elif msg_type == "ping":
                await websocket.send_json({"type": "pong", "data": {}})

    except WebSocketDisconnect:
        voice_ws_manager.disconnect(session_id)
    except Exception as e:
        logger.error(f"Voice WebSocket error: {e}")
        try:
            await websocket.send_json({"type": VoiceStreamEvent.ERROR, "data": {"message": str(e)}})
        except Exception:
            pass
        voice_ws_manager.disconnect(session_id)
