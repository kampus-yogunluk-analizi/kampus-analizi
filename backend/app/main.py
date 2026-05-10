from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import build_router
from app.services.density_service import DensityService
from app.websocket.manager import DensityWebSocket

app = FastAPI(title="Campus Density API")
density_service = DensityService()
density_socket = DensityWebSocket(density_service)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(build_router(density_service))


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await density_socket.handle(websocket)
