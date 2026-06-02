from datetime import datetime, timedelta
from statistics import mean, stdev

from sqlalchemy.orm import Session

from app.models.models import Building, DensityData


SIGNAL_MIN_DBM = -95
SIGNAL_MAX_DBM = -35
DEFAULT_CAPACITY = 120
ANOMALY_WINDOW = 10
TREND_WINDOW = 5
CONFIDENCE_DECAY_MINUTES = 10


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


def smooth_score(current: int, history: list[int]) -> int:
    """Exponential moving average — ağırlık güncel okumaya daha fazla."""
    if not history:
        return current
    alpha = 0.65
    result = current * alpha
    for i, s in enumerate(history[:4]):
        result += s * (1 - alpha) * (alpha**i)
    return round(clamp(result, 0, 100))


def calculate_confidence(
    signal_strength: float,
    timestamp: datetime,
    sample_count: int,
) -> int:
    """
    0-100 arası güven skoru.
    Sinyal kalitesi, verinin tazeliği ve örnek sayısına göre hesaplanır.
    """
    signal_q = clamp(
        (signal_strength - SIGNAL_MIN_DBM) / (SIGNAL_MAX_DBM - SIGNAL_MIN_DBM),
        0, 1,
    )
    age_min = (datetime.utcnow() - timestamp).total_seconds() / 60
    freshness = clamp(1 - age_min / CONFIDENCE_DECAY_MINUTES, 0, 1)
    sample_q = clamp(sample_count / 5, 0, 1)

    score = (signal_q * 0.4 + freshness * 0.4 + sample_q * 0.2) * 100
    return round(clamp(score, 0, 100))


def calculate_trend(scores: list[int]) -> str:
    """Son TREND_WINDOW okumaya göre artış/azalış yönü."""
    if len(scores) < 2:
        return "stable"
    first = mean(scores[: len(scores) // 2])
    second = mean(scores[len(scores) // 2 :])
    delta = second - first
    if delta > 5:
        return "rising"
    if delta < -5:
        return "falling"
    return "stable"


def is_anomaly(score: int, history: list[int]) -> bool:
    """Z-score tabanlı aykırı değer tespiti."""
    if len(history) < 4:
        return False
    mu = mean(history)
    sd = stdev(history) if len(history) > 1 else 0
    if sd < 5:
        return abs(score - mu) > 20
    return abs(score - mu) / sd > 2.5


def _get_recent_scores(db: Session, building_id: int, limit: int) -> list[int]:
    rows = (
        db.query(DensityData.density_score)
        .filter(DensityData.building_id == building_id)
        .order_by(DensityData.timestamp.desc(), DensityData.id.desc())
        .limit(limit)
        .all()
    )
    return [r[0] for r in rows if r[0] is not None]


def create_density_record(
    db: Session,
    building_id: int,
    wifi_count: int,
    bluetooth_count: int,
    signal_strength: float,
) -> DensityData:
    raw_score = calculate_density_score(
        wifi_count=wifi_count,
        bluetooth_count=bluetooth_count,
        signal_strength=signal_strength,
    )
    history = _get_recent_scores(db, building_id, ANOMALY_WINDOW)
    score = smooth_score(raw_score, history)

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
    db: Session | None = None,
) -> dict:
    wifi_count = density.wifi_count if density else 0
    bluetooth_count = density.bluetooth_count if density else 0
    signal_strength = density.signal_strength if density else SIGNAL_MIN_DBM
    score = (
        density.density_score
        if density and density.density_score is not None
        else calculate_density_score(wifi_count, bluetooth_count, signal_strength)
    )
    ts = density.timestamp if density else None

    # Ek analizler sadece DB bağlantısı varsa ve kayıt varsa
    confidence = 0
    trend = "stable"
    anomaly = False
    recent_count = 0

    if db and density:
        history = _get_recent_scores(db, building.id, TREND_WINDOW)
        recent_count = len(history)
        confidence = calculate_confidence(signal_strength, ts, recent_count)
        trend = calculate_trend(history)
        anomaly = is_anomaly(score, history)

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
        "timestamp": ts.isoformat() if ts else None,
        "confidence_score": confidence,
        "trend": trend,
        "is_anomaly": anomaly,
        "sample_count": recent_count,
    }


def get_latest_density_snapshot(db: Session) -> list[dict]:
    buildings = db.query(Building).order_by(Building.name).all()
    return [
        serialize_density(
            building,
            db.query(DensityData)
            .filter(DensityData.building_id == building.id)
            .order_by(DensityData.timestamp.desc(), DensityData.id.desc())
            .first(),
            db=db,
        )
        for building in buildings
    ]


def build_websocket_payload(db: Session) -> dict:
    return {
        "type": "density_snapshot",
        "generated_at": datetime.utcnow().isoformat(),
        "data": get_latest_density_snapshot(db),
    }


def get_building_history(
    db: Session,
    building_id: int,
    hours: int = 24,
) -> list[dict]:
    """Son N saatin saatlik ortalama yoğunluğunu döner."""
    since = datetime.utcnow() - timedelta(hours=hours)
    rows = (
        db.query(DensityData)
        .filter(
            DensityData.building_id == building_id,
            DensityData.timestamp >= since,
        )
        .order_by(DensityData.timestamp.asc())
        .all()
    )

    buckets: dict[int, list[int]] = {}
    for row in rows:
        hour = row.timestamp.replace(minute=0, second=0, microsecond=0)
        h = int(hour.timestamp())
        buckets.setdefault(h, []).append(row.density_score or 0)

    result = []
    for ts_epoch in sorted(buckets):
        scores = buckets[ts_epoch]
        avg = round(mean(scores))
        result.append({
            "hour": datetime.utcfromtimestamp(ts_epoch).isoformat(),
            "avg_intensity": avg,
            "density_level": classify_density(avg),
            "sample_count": len(scores),
        })
    return result
