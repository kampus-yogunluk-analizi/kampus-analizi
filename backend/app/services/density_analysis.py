from datetime import datetime

from sqlalchemy.orm import Session

from app.models.models import Building, DensityData


SIGNAL_MIN_DBM = -95
SIGNAL_MAX_DBM = -35
DEFAULT_CAPACITY = 120


def clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(value, maximum))


def calculate_density_score(
    wifi_count: int,
    bluetooth_count: int,
    signal_strength: float,
    capacity: int = DEFAULT_CAPACITY,
) -> int:
    weighted_devices = max(wifi_count, 0) + (max(bluetooth_count, 0) * 0.65)
    device_load = clamp(weighted_devices / max(capacity, 1), 0, 1)

    signal_quality = clamp(
        (signal_strength - SIGNAL_MIN_DBM) / (SIGNAL_MAX_DBM - SIGNAL_MIN_DBM),
        0,
        1,
    )

    density_score = ((device_load * 0.7) + (signal_quality * 0.3)) * 100
    return round(clamp(density_score, 0, 100))


def classify_density(score: int) -> str:
    if score >= 70:
        return "high"
    if score >= 35:
        return "medium"
    return "low"


def create_density_record(
    db: Session,
    building_id: int,
    wifi_count: int,
    bluetooth_count: int,
    signal_strength: float,
) -> DensityData:
    score = calculate_density_score(
        wifi_count=wifi_count,
        bluetooth_count=bluetooth_count,
        signal_strength=signal_strength,
    )

    density = DensityData(
        building_id=building_id,
        wifi_count=wifi_count,
        bluetooth_count=bluetooth_count,
        signal_strength=signal_strength,
        density_score=score,
    )
    db.add(density)
    db.commit()
    db.refresh(density)
    return density


def serialize_density(
    building: Building,
    density: DensityData | None,
) -> dict:
    wifi_count = density.wifi_count if density else 0
    bluetooth_count = density.bluetooth_count if density else 0
    signal_strength = density.signal_strength if density else SIGNAL_MIN_DBM
    score = (
        density.density_score
        if density and density.density_score is not None
        else calculate_density_score(wifi_count, bluetooth_count, signal_strength)
    )

    return {
        "building_id": building.id,
        "name": building.name,
        "lat": building.latitude,
        "lng": building.longitude,
        "wifi_count": wifi_count,
        "bluetooth_count": bluetooth_count,
        "signal_strength": signal_strength,
        "intensity": score,
        "density_score": score,
        "density_level": classify_density(score),
        "timestamp": density.timestamp.isoformat() if density else None,
    }


def get_latest_density_snapshot(db: Session) -> list[dict]:
    snapshot = []
    buildings = db.query(Building).order_by(Building.name).all()

    for building in buildings:
        density = (
            db.query(DensityData)
            .filter(DensityData.building_id == building.id)
            .order_by(DensityData.timestamp.desc(), DensityData.id.desc())
            .first()
        )
        snapshot.append(serialize_density(building, density))

    return snapshot


def build_websocket_payload(db: Session) -> dict:
    return {
        "type": "density_snapshot",
        "generated_at": datetime.utcnow().isoformat(),
        "data": get_latest_density_snapshot(db),
    }
