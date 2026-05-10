import asyncio
import json

from fastapi import WebSocket, WebSocketDisconnect

from app.services.density_service import DensityService


class DensityWebSocket:
    def __init__(self, density_service: DensityService) -> None:
        self._density_service = density_service

    async def handle(self, websocket: WebSocket) -> None:
        await websocket.accept()
        try:
            while True:
                snapshot = self._density_service.simulate_tick()
                await websocket.send_text(json.dumps(snapshot.model_dump()))
                await asyncio.sleep(2)
        except WebSocketDisconnect:
            return
