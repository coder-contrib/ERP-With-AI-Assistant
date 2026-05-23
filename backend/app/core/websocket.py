import asyncio
import json
from fastapi import WebSocket, WebSocketDisconnect
from typing import Dict, Set
import logging

logger = logging.getLogger(__name__)


class ConnectionManager:
    """Manages WebSocket connections for real-time features."""

    def __init__(self):
        self._connections: Dict[str, Set[WebSocket]] = {}
        self._user_connections: Dict[int, Set[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, channel: str, user_id: int | None = None):
        await websocket.accept()
        if channel not in self._connections:
            self._connections[channel] = set()
        self._connections[channel].add(websocket)
        if user_id:
            if user_id not in self._user_connections:
                self._user_connections[user_id] = set()
            self._user_connections[user_id].add(websocket)

    def disconnect(self, websocket: WebSocket, channel: str, user_id: int | None = None):
        if channel in self._connections:
            self._connections[channel].discard(websocket)
        if user_id and user_id in self._user_connections:
            self._user_connections[user_id].discard(websocket)

    async def broadcast(self, channel: str, message: dict):
        if channel not in self._connections:
            return
        data = json.dumps(message)
        disconnected = set()
        for ws in self._connections[channel]:
            try:
                await ws.send_text(data)
            except Exception:
                disconnected.add(ws)
        for ws in disconnected:
            self._connections[channel].discard(ws)

    async def send_to_user(self, user_id: int, message: dict):
        if user_id not in self._user_connections:
            return
        data = json.dumps(message)
        disconnected = set()
        for ws in self._user_connections[user_id]:
            try:
                await ws.send_text(data)
            except Exception:
                disconnected.add(ws)
        for ws in disconnected:
            self._user_connections[user_id].discard(ws)

    async def broadcast_all(self, message: dict):
        data = json.dumps(message)
        for channel_connections in self._connections.values():
            for ws in channel_connections:
                try:
                    await ws.send_text(data)
                except Exception:
                    pass

    @property
    def active_connections(self) -> int:
        return sum(len(conns) for conns in self._connections.values())


manager = ConnectionManager()


def get_ws_manager() -> ConnectionManager:
    return manager
