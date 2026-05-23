from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query
from app.core.websocket import get_ws_manager
from app.core.security import decode_access_token
import json

router = APIRouter()


@router.websocket("/ws/dashboard")
async def ws_dashboard(websocket: WebSocket, token: str = Query(None)):
    user_id = _verify_token(token)
    if not user_id:
        await websocket.close(code=4001)
        return

    mgr = get_ws_manager()
    await mgr.connect(websocket, "dashboard", user_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        mgr.disconnect(websocket, "dashboard", user_id)


@router.websocket("/ws/notifications")
async def ws_notifications(websocket: WebSocket, token: str = Query(None)):
    user_id = _verify_token(token)
    if not user_id:
        await websocket.close(code=4001)
        return

    mgr = get_ws_manager()
    await mgr.connect(websocket, "notifications", user_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        mgr.disconnect(websocket, "notifications", user_id)


@router.websocket("/ws/inventory")
async def ws_inventory(websocket: WebSocket, token: str = Query(None)):
    user_id = _verify_token(token)
    if not user_id:
        await websocket.close(code=4001)
        return

    mgr = get_ws_manager()
    await mgr.connect(websocket, "inventory", user_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        mgr.disconnect(websocket, "inventory", user_id)


@router.websocket("/ws/ai")
async def ws_ai_stream(websocket: WebSocket, token: str = Query(None)):
    user_id = _verify_token(token)
    if not user_id:
        await websocket.close(code=4001)
        return

    mgr = get_ws_manager()
    await mgr.connect(websocket, "ai", user_id)
    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            # Stream AI response back token by token
            await _stream_ai_response(websocket, user_id, message)
    except WebSocketDisconnect:
        mgr.disconnect(websocket, "ai", user_id)


async def _stream_ai_response(websocket: WebSocket, user_id: int, message: dict):
    """Simulate streaming AI response. Replace with real LLM streaming later."""
    query = message.get("query", "")
    await websocket.send_text(json.dumps({"type": "ai_start", "query": query}))

    response = f"I'm analyzing your question: '{query}'. Let me check the data for you."
    for i, char in enumerate(response):
        await websocket.send_text(json.dumps({"type": "ai_token", "token": char, "index": i}))
        import asyncio
        await asyncio.sleep(0.02)

    await websocket.send_text(json.dumps({"type": "ai_end", "full_response": response}))


def _verify_token(token: str | None) -> int | None:
    if not token:
        return None
    payload = decode_access_token(token)
    if not payload:
        return None
    return int(payload.get("sub", 0))
