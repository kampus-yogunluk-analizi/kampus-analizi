from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database.config import get_db
from app.models.models import Building, DensityData
from app.services.density_analysis import (
    build_websocket_payload,
    create_density_record,
    get_building_history,
    get_latest_density_snapshot,
    serialize_density,
)
from app.services.rf_analysis import (
    build_rf_report,
    calculate_snr_db,
    calculate_shannon_capacity_mbps,
    estimate_ber,
    estimate_distance_m,
    calculate_interference_score,
    recommend_channel,
    classify_channel_quality,
    ber_to_quality,
    WIFI_CHANNEL_BW_MHZ,
    BLE_TX_POWER_DBM,
    INDOOR_PATH_LOSS_EXP,
    NOISE_FLOOR_DBM,
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


@router.get("/buildings/{building_id}/rf-analysis")
def get_rf_analysis(
    building_id: int,
    db: Session = Depends(get_db),
):
    """
    Bina için detaylı RF analizi:
    - Log-Distance Path Loss → mesafe tahmini
    - SNR → sinyal/gürültü oranı
    - Shannon kapasitesi → teorik Mbps
    - BER → bit hata oranı (BPSK)
    - Kanal girişim skoru + bant önerisi
    - Formüller (demo/sunum için)
    """
    from statistics import mean

    building = db.query(Building).filter(Building.id == building_id).first()
    if building is None:
        raise HTTPException(status_code=404, detail="Bina bulunamadı")

    latest = (
        db.query(DensityData)
        .filter(DensityData.building_id == building_id)
        .order_by(DensityData.timestamp.desc())
        .first()
    )

    if latest is None:
        return {"building_id": building_id, "message": "Ölçüm verisi yok"}

    rssi = latest.signal_strength
    device_count = (latest.wifi_count or 0) + (latest.bluetooth_count or 0)
    snr = calculate_snr_db(rssi)
    capacity_mbps = calculate_shannon_capacity_mbps(snr, WIFI_CHANNEL_BW_MHZ)
    ber = estimate_ber(snr)
    distance = estimate_distance_m(rssi)
    interference = calculate_interference_score(device_count, rssi)

    # Son 10 ölçümden ortalama RSSI dağılımı
    recent_rows = (
        db.query(DensityData.signal_strength)
        .filter(DensityData.building_id == building_id)
        .order_by(DensityData.timestamp.desc())
        .limit(10)
        .all()
    )
    rssi_list = [r[0] for r in recent_rows if r[0] is not None]
    avg_rssi = round(mean(rssi_list), 2) if rssi_list else rssi

    return {
        "building_id": building_id,
        "building_name": building.name,
        "measurement": {
            "rssi_dbm": rssi,
            "avg_rssi_10samples": avg_rssi,
            "device_count": device_count,
            "wifi_count": latest.wifi_count,
            "bluetooth_count": latest.bluetooth_count,
        },
        "path_loss": {
            "model": "Log-Distance Path Loss",
            "formula": f"d = 10^((TX_Power - RSSI) / (10·n))",
            "parameters": {
                "tx_power_dbm": BLE_TX_POWER_DBM,
                "path_loss_exponent_n": INDOOR_PATH_LOSS_EXP,
                "rssi_dbm": rssi,
            },
            "estimated_distance_m": distance,
        },
        "snr": {
            "formula": "SNR = RSSI - NoiseFloor",
            "noise_floor_dbm": NOISE_FLOOR_DBM,
            "snr_db": snr,
            "channel_quality": classify_channel_quality(snr),
        },
        "shannon": {
            "formula": "C = B · log₂(1 + SNR_lin)",
            "bandwidth_mhz": WIFI_CHANNEL_BW_MHZ,
            "theoretical_capacity_mbps": capacity_mbps,
            "channel_quality": classify_channel_quality(snr),
        },
        "ber": {
            "formula": "BER = ½·erfc(√(SNR_lin))  [BPSK/AWGN]",
            "modulation": "BPSK",
            "channel_model": "AWGN",
            "ber_value": ber,
            "quality": ber_to_quality(ber),
        },
        "interference": {
            "score": interference,
            "recommended_channel": recommend_channel(interference, device_count),
            "explanation": (
                "Yüksek cihaz yoğunluğu + zayıf sinyal → yüksek kanal girişimi"
                if interference >= 60
                else "Normal kanal yükü"
            ),
        },
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
