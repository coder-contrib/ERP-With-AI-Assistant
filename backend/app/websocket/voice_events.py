import base64
import json
from fastapi import WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from app.services.voice_service import VoiceService
from app.ai.voice_orchestrator import VoiceOrchestrator
import logging

logger = logging.getLogger(__name__)


async def handle_voice_websocket(websocket: WebSocket, session_id: str, db: Session):
    """Handle realtime voice WebSocket connection.
    
    Protocol:
    Client → Server:
      {"type": "audio", "data": "<base64 audio>"}
      {"type": "text", "data": {"message": "..."}}
    
    Server → Client:
      {"type": "transcription_partial", "data": {"text": "..."}}
      {"type": "transcription_complete", "data": {"text": "...", "language": "..."}}
      {"type": "tool_call_started", "data": {"tool": "..."}}
      {"type": "tool_call_finished", "data": {"tool": "..."}}
      {"type": "ai_response_complete", "data": {"text": "...", "tools_used": [...]}}
      {"type": "ai_speaking", "data": {}}
      {"type": "audio_chunk", "data": {"bytes": "<base64>"}}
      {"type": "ai_finished", "data": {}}
      {"type": "error", "data": {"message": "..."}}
    """
    await websocket.accept()
    voice_service = VoiceService()
    orchestrator = VoiceOrchestrator(db)

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                await _send(websocket, "error", {"message": "Invalid JSON"})
                continue

            msg_type = message.get("type")

            if msg_type == "audio":
                audio_b64 = message.get("data", "")
                try:
                    audio_bytes = base64.b64decode(audio_b64)
                except Exception:
                    await _send(websocket, "error", {"message": "Invalid base64 audio"})
                    continue

                # Transcribe
                transcription = await voice_service.transcribe(audio_bytes)
                text = transcription.get("text", "")
                language = transcription.get("language_detected", "ar")

                if not text.strip():
                    await _send(websocket, "error", {"message": "Could not transcribe audio"})
                    continue

                await _send(websocket, "transcription_complete", {"text": text, "language": language})

                # Process through AI
                result = orchestrator.process_voice_message(session_id, text)

                await _send(websocket, "ai_response_complete", {
                    "text": result["text"],
                    "tools_used": result["tools_used"],
                })

                # Generate TTS
                if result["text"]:
                    await _send(websocket, "ai_speaking", {})
                    audio_data = await voice_service.text_to_speech(result["text"])
                    if audio_data:
                        audio_b64_out = base64.b64encode(audio_data).decode()
                        await _send(websocket, "audio_chunk", {"bytes": audio_b64_out})

                await _send(websocket, "ai_finished", {})

            elif msg_type == "text":
                data = message.get("data", {})
                text = data.get("message", "").strip()

                if not text:
                    continue

                # Process through AI
                result = orchestrator.process_voice_message(session_id, text)

                await _send(websocket, "ai_response_complete", {
                    "text": result["text"],
                    "tools_used": result["tools_used"],
                })

                # Generate TTS
                if result["text"]:
                    await _send(websocket, "ai_speaking", {})
                    audio_data = await voice_service.text_to_speech(result["text"])
                    if audio_data:
                        audio_b64_out = base64.b64encode(audio_data).decode()
                        await _send(websocket, "audio_chunk", {"bytes": audio_b64_out})

                await _send(websocket, "ai_finished", {})

    except WebSocketDisconnect:
        logger.info(f"Voice WebSocket disconnected: {session_id}")
    except Exception as e:
        logger.error(f"Voice WebSocket error: {e}")
        try:
            await _send(websocket, "error", {"message": str(e)})
        except Exception:
            pass


async def _send(websocket: WebSocket, event_type: str, data: dict):
    await websocket.send_text(json.dumps({"type": event_type, "data": data}))
