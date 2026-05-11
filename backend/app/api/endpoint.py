from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.config import get_db
from app.models.models import Building
from app.services.density_analysis import (
    build_websocket_payload,
    create_density_record,
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

    result = serialize_density(building, density)

    await websocket_manager.broadcast(
        build_websocket_payload(db),
    )

    return {
        "status": "success",
        "result": result,
    }
