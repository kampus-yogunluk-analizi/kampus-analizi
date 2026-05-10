from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware

from app.api.endpoint import router 
from app.database.config import engine, SessionLocal
from app.database.seed import seed_campus_data
from app.models.models import Base

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Campus Density API")

@app.on_event("startup")
async def startup_event():
    """Uygulama kalkarken veri tabanına kampüs koordinatlarını gömer."""
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
    await websocket.accept()
    while True:
        data = await websocket.receive_text()
        await websocket.send_text(f"Message received: {data}")