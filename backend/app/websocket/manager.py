import json
from typing import Any

from fastapi import WebSocket


class WebSocketManager:
    def __init__(self) -> None:
        self.active_connections: set[WebSocket] = set()

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self.active_connections.add(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        self.active_connections.discard(websocket)

    async def send_json(self, websocket: WebSocket, payload: dict[str, Any]) -> None:
        await websocket.send_text(json.dumps(payload, ensure_ascii=False))

    async def broadcast(self, payload: dict[str, Any]) -> None:
        disconnected = []

        for connection in self.active_connections:
            try:
                await self.send_json(connection, payload)
            except Exception:
                disconnected.append(connection)

        for connection in disconnected:
            self.disconnect(connection)


websocket_manager = WebSocketManager()
