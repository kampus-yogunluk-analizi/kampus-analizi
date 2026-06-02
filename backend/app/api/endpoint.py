from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.config import get_db
from app.models.models import Building
from app.services.density_analysis import (
    build_websocket_payload,
    create_density_record,
    get_building_history,
    get_latest_density_snapshot,
    serialize_density,
)
from app.websocket.manager import websocket_manager

router = APIRouter()


class DensityUpdate(BaseModel):
    building_id: int = Field(..., gt=0)
    wifi_count: int = Field(..., ge=0)
    bluetooth_count: int = Field(..., ge=0)
    signal_strength: float = Field(..., ge=-120, le=0)


@router.get("/heatmap-data")
def get_heatmap_data(db: Session = Depends(get_db)):
    return get_latest_density_snapshot(db)


@router.get("/buildings/{building_id}/history")
def get_history(
    building_id: int,
    hours: int = Query(default=24, ge=1, le=168),
    db: Session = Depends(get_db),
):
    building = db.query(Building).filter(Building.id == building_id).first()
    if building is None:
        raise HTTPException(status_code=404, detail="Bina bulunamadı")
    return {
        "building_id": building_id,
        "building_name": building.name,
        "hours": hours,
        "history": get_building_history(db, building_id, hours),
    }


@router.get("/buildings/{building_id}/stats")
def get_building_stats(
    building_id: int,
    db: Session = Depends(get_db),
):
    """Son 24 saatlik özet istatistikler: peak saat, ortalama, max."""
    from app.models.models import DensityData
    from datetime import datetime, timedelta
    from statistics import mean

    building = db.query(Building).filter(Building.id == building_id).first()
    if building is None:
        raise HTTPException(status_code=404, detail="Bina bulunamadı")

    since = datetime.utcnow() - timedelta(hours=24)
    rows = (
        db.query(DensityData)
        .filter(DensityData.building_id == building_id, DensityData.timestamp >= since)
        .order_by(DensityData.timestamp.asc())
        .all()
    )

    if not rows:
        return {"building_id": building_id, "message": "Yeterli veri yok"}

    scores = [r.density_score or 0 for r in rows]
    peak_row = max(rows, key=lambda r: r.density_score or 0)

    return {
        "building_id": building_id,
        "building_name": building.name,
        "avg_intensity": round(mean(scores)),
        "max_intensity": max(scores),
        "min_intensity": min(scores),
        "peak_hour": peak_row.timestamp.strftime("%H:00"),
        "total_readings": len(rows),
    }


@router.post("/update-density")
async def update_density(
    payload: DensityUpdate,
    db: Session = Depends(get_db),
):
    building = (
        db.query(Building)
        .filter(Building.id == payload.building_id)
        .first()
    )

    if building is None:
        raise HTTPException(status_code=404, detail="Bina bulunamadı")

    density = create_density_record(
        db=db,
        building_id=payload.building_id,
        wifi_count=payload.wifi_count,
        bluetooth_count=payload.bluetooth_count,
        signal_strength=payload.signal_strength,
    )

    result = serialize_density(building, density, db=db)

    await websocket_manager.broadcast(build_websocket_payload(db))

    return {"status": "success", "result": result}
