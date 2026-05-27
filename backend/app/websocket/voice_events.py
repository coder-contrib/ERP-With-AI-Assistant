import asyncio
import base64
import json
from fastapi import WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from app.services.voice_service import VoiceService
from app.ai.voice_orchestrator import VoiceOrchestrator
import logging

logger = logging.getLogger(__name__)


async def handle_voice_websocket(websocket: WebSocket, session_id: str, db: Session):
    """Handle realtime voice WebSocket connection with live streaming support.

    Protocol:
    Client → Server:
      {"type": "audio", "data": "<base64 audio>"}           — batch: full recording
      {"type": "stream_start"}                               — begin live stream
      {"type": "stream_audio", "data": "<base64 chunk>"}    — live audio chunk
      {"type": "stream_stop"}                                — end live stream, process
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
    streamer = None
    stream_task = None

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                await _send(websocket, "error", {"message": "Invalid JSON"})
                continue

            msg_type = message.get("type")

            # ─── Live Streaming Mode ─────────────────────────────────
            if msg_type == "stream_start":
                # Start a streaming transcription session
                language = message.get("language", "ar")
                streamer = await voice_service.create_streaming_transcription(language)
                await streamer.connect()
                # Start background task to relay partial results
                stream_task = asyncio.create_task(
                    _relay_stream_results(websocket, streamer)
                )
                await _send(websocket, "stream_started", {})

            elif msg_type == "stream_audio":
                # Receive a live audio chunk and forward to streamer
                if streamer is None:
                    await _send(websocket, "error", {"message": "No active stream. Send stream_start first."})
                    continue
                audio_b64 = message.get("data", "")
                try:
                    audio_bytes = base64.b64decode(audio_b64)
                    await streamer.send_audio(audio_bytes)
                except Exception as e:
                    await _send(websocket, "error", {"message": f"Audio chunk error: {e}"})

            elif msg_type == "stream_stop":
                # End streaming, get final transcription, process through AI
                if streamer is None:
                    continue

                # Stop relaying partial results
                if stream_task:
                    stream_task.cancel()
                    try:
                        await stream_task
                    except asyncio.CancelledError:
                        pass

                # Get final transcription
                final_text = await streamer.finish()
                await streamer.close()
                streamer = None

                if not final_text.strip():
                    await _send(websocket, "error", {"message": "No speech detected"})
                    await _send(websocket, "ai_finished", {})
                    continue

                await _send(websocket, "transcription_complete", {
                    "text": final_text,
                    "language": "ar",
                })

                # Process through AI
                result = orchestrator.process_voice_message(session_id, final_text)

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

            # ─── Batch Mode (full recording) ────────────────────────
            elif msg_type == "audio":
                audio_b64 = message.get("data", "")
                try:
                    audio_bytes = base64.b64decode(audio_b64)
                except Exception:
                    await _send(websocket, "error", {"message": "Invalid base64 audio"})
                    continue

                transcription = await voice_service.transcribe(audio_bytes)
                text = transcription.get("text", "")
                language = transcription.get("language_detected", "ar")

                if not text.strip():
                    await _send(websocket, "error", {"message": "Could not transcribe audio"})
                    continue

                await _send(websocket, "transcription_complete", {"text": text, "language": language})

                result = orchestrator.process_voice_message(session_id, text)

                await _send(websocket, "ai_response_complete", {
                    "text": result["text"],
                    "tools_used": result["tools_used"],
                })

                if result["text"]:
                    await _send(websocket, "ai_speaking", {})
                    audio_data = await voice_service.text_to_speech(result["text"])
                    if audio_data:
                        audio_b64_out = base64.b64encode(audio_data).decode()
                        await _send(websocket, "audio_chunk", {"bytes": audio_b64_out})

                await _send(websocket, "ai_finished", {})

            # ─── Text Mode ───────────────────────────────────────
            elif msg_type == "text":
                data = message.get("data", {})
                text = data.get("message", "").strip()
                if not text:
                    continue

                result = orchestrator.process_voice_message(session_id, text)

                await _send(websocket, "ai_response_complete", {
                    "text": result["text"],
                    "tools_used": result["tools_used"],
                })

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
    finally:
        # Cleanup streaming session
        if stream_task and not stream_task.done():
            stream_task.cancel()
        if streamer:
            await streamer.close()


async def _relay_stream_results(websocket: WebSocket, streamer):
    """Background task: relay partial transcription results to the client in real-time."""
    accumulated_text = ""
    try:
        while True:
            result = await streamer.get_result(timeout=0.15)
            if result is None:
                continue

            if result.get("type") == "utterance_end":
                continue

            text = result.get("text", "")
            is_final = result.get("is_final", False)

            if is_final:
                accumulated_text += text + " "
                await _send(websocket, "transcription_partial", {
                    "text": accumulated_text.strip(),
                    "is_final_segment": True,
                })
            else:
                # Show accumulated + current partial
                display_text = (accumulated_text + text).strip()
                await _send(websocket, "transcription_partial", {
                    "text": display_text,
                    "is_final_segment": False,
                })

    except asyncio.CancelledError:
        pass
    except Exception as e:
        logger.error(f"Stream relay error: {e}")


async def _send(websocket: WebSocket, event_type: str, data: dict):
    await websocket.send_text(json.dumps({"type": event_type, "data": data}))
