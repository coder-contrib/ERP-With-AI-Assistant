import base64
import json
from fastapi import APIRouter, Depends, UploadFile, File, Form, WebSocket, Query
from fastapi.responses import StreamingResponse, Response
from sqlalchemy.orm import Session
from app.database import get_db
from app.core.deps import get_current_user
from app.models.users import User
from app.services.voice_service import VoiceService
from app.ai.voice_orchestrator import VoiceOrchestrator
from app.schemas.voice import (
    TranscribeResponse,
    VoiceRespondRequest,
    VoiceRespondResponse,
    VoiceLanguage,
)
from app.websocket.voice_events import handle_voice_websocket

router = APIRouter()


@router.post("/transcribe", response_model=TranscribeResponse)
async def transcribe_audio(
    file: UploadFile = File(...),
    language: str = Form(default="auto"),
    current_user: User = Depends(get_current_user),
):
    """Transcribe audio file to text using Whisper.
    Supports Arabic, Egyptian dialect, English, and Franco-Arabic.
    """
    audio_data = await file.read()
    voice_service = VoiceService()
    result = await voice_service.transcribe(audio_data, language)
    return TranscribeResponse(**result)


@router.post("/respond", response_model=VoiceRespondResponse)
async def voice_respond(
    file: UploadFile = File(...),
    session_id: str = Form(default="voice-default"),
    language: str = Form(default="auto"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Full voice pipeline: audio → transcription → Claude AI → text response.
    Use /voice/respond/audio for TTS audio output.
    """
    audio_data = await file.read()
    voice_service = VoiceService()

    # Step 1: Transcribe
    transcription = await voice_service.transcribe(audio_data, language)

    # Step 2: Process through Claude
    orchestrator = VoiceOrchestrator(db)
    result = orchestrator.process_voice_message(session_id, transcription["text"])

    return VoiceRespondResponse(
        transcript=result["text"],
        tools_used=result["tools_used"],
        language=transcription["language_detected"],
        session_id=session_id,
    )


@router.post("/respond/audio")
async def voice_respond_audio(
    file: UploadFile = File(...),
    session_id: str = Form(default="voice-default"),
    language: str = Form(default="auto"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Full voice pipeline returning audio: audio → transcription → Claude → TTS audio stream."""
    audio_data = await file.read()
    voice_service = VoiceService()

    # Transcribe
    transcription = await voice_service.transcribe(audio_data, language)

    # Process through Claude
    orchestrator = VoiceOrchestrator(db)
    result = orchestrator.process_voice_message(session_id, transcription["text"])

    # Generate TTS
    async def audio_stream():
        async for chunk in voice_service.text_to_speech_stream(result["text"]):
            yield chunk

    return StreamingResponse(
        audio_stream(),
        media_type="audio/mpeg",
        headers={
            "X-Transcript": base64.b64encode(result["text"].encode()).decode(),
            "X-Tools-Used": json.dumps(result["tools_used"]),
            "X-Language": transcription["language_detected"],
        },
    )


@router.post("/tts")
async def text_to_speech(
    text: str = Form(...),
    current_user: User = Depends(get_current_user),
):
    """Convert text to speech audio."""
    voice_service = VoiceService()
    audio_data = await voice_service.text_to_speech(text)
    return Response(content=audio_data, media_type="audio/mpeg")


@router.post("/tts/stream")
async def text_to_speech_stream(
    text: str = Form(...),
    current_user: User = Depends(get_current_user),
):
    """Stream text-to-speech audio for low-latency playback."""
    voice_service = VoiceService()
    return StreamingResponse(
        voice_service.text_to_speech_stream(text),
        media_type="audio/mpeg",
    )


@router.post("/chat")
async def voice_chat_text(
    data: VoiceRespondRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Voice-optimized text chat (returns concise spoken-style responses + TTS audio)."""
    if not data.text:
        return {"error": "No text provided"}

    orchestrator = VoiceOrchestrator(db)
    result = orchestrator.process_voice_message(data.session_id, data.text)

    # Generate audio
    voice_service = VoiceService()
    audio_bytes = await voice_service.text_to_speech(result["text"])
    audio_b64 = base64.b64encode(audio_bytes).decode()

    return {
        "text": result["text"],
        "audio": audio_b64,
        "tools_used": result["tools_used"],
        "session_id": data.session_id,
    }


@router.websocket("/ws/{session_id}")
async def voice_websocket_endpoint(
    websocket: WebSocket,
    session_id: str,
    db: Session = Depends(get_db),
):
    """WebSocket endpoint for realtime voice interactions."""
    await handle_voice_websocket(websocket, session_id, db)
