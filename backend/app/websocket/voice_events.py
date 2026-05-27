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
      {"type": "stream_start", "language": "ar"}             — begin live stream
      {"type": "stream_audio", "data": "<base64 chunk>"}    — live audio chunk
      {"type": "stream_stop"}                                — end live stream, process
      {"type": "barge_in"}                                   — interrupt AI, start listening
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
      {"type": "barge_in_ack", "data": {}}
      {"type": "error", "data": {"message": "..."}}
    """
    await websocket.accept()
    voice_service = VoiceService()
    orchestrator = VoiceOrchestrator(db)
    streamer = None
    stream_task = None
    ai_processing_task = None
    is_speaking = False

    async def cancel_ai_processing():
        """Cancel any in-progress AI processing or TTS generation."""
        nonlocal ai_processing_task, is_speaking
        if ai_processing_task and not ai_processing_task.done():
            ai_processing_task.cancel()
            try:
                await ai_processing_task
            except asyncio.CancelledError:
                pass
            ai_processing_task = None
        is_speaking = False

    async def process_and_respond(text: str):
        """Process transcribed text through AI and send TTS response."""
        nonlocal is_speaking
        try:
            result = orchestrator.process_voice_message(session_id, text)

            await _send(websocket, "ai_response_complete", {
                "text": result["text"],
                "tools_used": result["tools_used"],
            })

            if result["text"]:
                is_speaking = True
                await _send(websocket, "ai_speaking", {})
                audio_data = await voice_service.text_to_speech(result["text"])
                if audio_data and is_speaking:
                    audio_b64_out = base64.b64encode(audio_data).decode()
                    await _send(websocket, "audio_chunk", {"bytes": audio_b64_out})

            if is_speaking:
                is_speaking = False
                await _send(websocket, "ai_finished", {})
        except asyncio.CancelledError:
            logger.info(f"AI processing cancelled (barge-in): {session_id}")
            raise

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                await _send(websocket, "error", {"message": "Invalid JSON"})
                continue

            msg_type = message.get("type")

            # ─── Barge-In: Interrupt AI ──────────────────────────────
            if msg_type == "barge_in":
                await cancel_ai_processing()
                # Also cancel any active streamer from previous session
                if stream_task and not stream_task.done():
                    stream_task.cancel()
                    try:
                        await stream_task
                    except asyncio.CancelledError:
                        pass
                if streamer:
                    await streamer.close()
                    streamer = None
                await _send(websocket, "barge_in_ack", {})

            # ─── Live Streaming Mode ─────────────────────────────────
            elif msg_type == "stream_start":
                # Cancel any ongoing AI processing first
                await cancel_ai_processing()

                language = message.get("language", "ar")
                streamer = await voice_service.create_streaming_transcription(language)
                await streamer.connect()
                stream_task = asyncio.create_task(
                    _relay_stream_results(websocket, streamer)
                )
                await _send(websocket, "stream_started", {})

            elif msg_type == "stream_audio":
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
                if streamer is None:
                    continue

                if stream_task:
                    stream_task.cancel()
                    try:
                        await stream_task
                    except asyncio.CancelledError:
                        pass

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

                # Process in a cancellable task (supports barge-in during AI processing)
                ai_processing_task = asyncio.create_task(
                    process_and_respond(final_text)
                )

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

                ai_processing_task = asyncio.create_task(
                    process_and_respond(text)
                )

            # ─── Text Mode ───────────────────────────────────────
            elif msg_type == "text":
                data = message.get("data", {})
                text = data.get("message", "").strip()
                if not text:
                    continue

                ai_processing_task = asyncio.create_task(
                    process_and_respond(text)
                )

    except WebSocketDisconnect:
        logger.info(f"Voice WebSocket disconnected: {session_id}")
    except Exception as e:
        logger.error(f"Voice WebSocket error: {e}")
        try:
            await _send(websocket, "error", {"message": str(e)})
        except Exception:
            pass
    finally:
        if ai_processing_task and not ai_processing_task.done():
            ai_processing_task.cancel()
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
