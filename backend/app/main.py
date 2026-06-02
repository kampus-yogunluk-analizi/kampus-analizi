import asyncio

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

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


@app.get("/ws-test", response_class=HTMLResponse)
async def websocket_test_page() -> str:
    return """
    <!doctype html>
    <html lang="tr">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>WebSocket Test</title>
        <style>
          body { font-family: system-ui, sans-serif; margin: 32px; }
          #status { font-weight: 700; }
          pre { background: #111827; color: #d1fae5; padding: 16px; overflow: auto; }
          button { padding: 10px 14px; margin-right: 8px; cursor: pointer; }
        </style>
      </head>
      <body>
        <h1>WebSocket Test</h1>
        <p>Durum: <span id="status">hazır</span></p>
        <button onclick="connect()">Bağlan</button>
        <button onclick="disconnect()">Kapat</button>
        <pre id="log"></pre>
        <script>
          let socket;
          const statusEl = document.getElementById("status");
          const logEl = document.getElementById("log");

          function log(message, data) {
            const value = data ? `${message} ${JSON.stringify(data, null, 2)}` : message;
            logEl.textContent = `${new Date().toLocaleTimeString()} - ${value}\\n\\n${logEl.textContent}`;
          }

          function connect() {
            const protocol = location.protocol === "https:" ? "wss" : "ws";
            socket = new WebSocket(`${protocol}://${location.host}/ws`);

            socket.onopen = () => {
              statusEl.textContent = "bağlandı";
              log("WebSocket bağlantısı açıldı");
            };
            socket.onmessage = (event) => {
              log("Mesaj geldi:", JSON.parse(event.data));
            };
            socket.onerror = (event) => {
              statusEl.textContent = "hata";
              log("WebSocket hatası");
              console.error(event);
            };
            socket.onclose = (event) => {
              statusEl.textContent = "kapandı";
              log(`WebSocket kapandı: ${event.code}`);
            };
          }

          function disconnect() {
            if (socket) socket.close();
          }

          connect();
        </script>
      </body>
    </html>
    """


@app.websocket("/ws")
@app.websocket("/api/v1/ws")
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
    except WebSocketDisconnect:
        pass
    finally:
        websocket_manager.disconnect(websocket)
