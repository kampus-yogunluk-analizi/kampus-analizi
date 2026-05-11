import asyncio

from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware

from app.api.endpoint import router 
from app.database.config import engine, SessionLocal
from app.database.migrations import ensure_density_columns
from app.database.seed import seed_campus_data
from app.models.models import Base
from app.services.density_analysis import build_websocket_payload
from app.websocket.manager import websocket_manager

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Campus Density API")

@app.on_event("startup")
async def startup_event():
    """Uygulama kalkarken veri tabanına kampüs koordinatlarını gömer."""
    ensure_density_columns()
    db = SessionLocal()
    try:
        seed_campus_data(db)
        print("İnönü Üniversitesi kampüs koordinatları başarıyla yüklendi.")
    finally:
        db.close()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api/v1")

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await websocket_manager.connect(websocket)
    try:
        while True:
            db = SessionLocal()
            try:
                await websocket_manager.send_json(
                    websocket,
                    build_websocket_payload(db),
                )
            finally:
                db.close()

            await asyncio.sleep(2)
    finally:
        websocket_manager.disconnect(websocket)
