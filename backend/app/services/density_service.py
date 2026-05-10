from __future__ import annotations

from datetime import datetime, timezone
import random

from app.models.schemas import AccessPoint, ConnectionEvent, DensitySnapshot, ZoneDensity


class DensityService:
    def __init__(self) -> None:
        self._access_points = [
            AccessPoint(
                id=1,
                name="Kutuphane AP",
                zone_id="library",
                lat=41.0102,
                lng=29.0110,
                map_x=0.28,
                map_y=0.28,
                capacity=90,
            ),
            AccessPoint(
                id=2,
                name="Kafeterya AP",
                zone_id="cafeteria",
                lat=41.0110,
                lng=29.0142,
                map_x=0.70,
                map_y=0.34,
                capacity=120,
            ),
            AccessPoint(
                id=3,
                name="Derslikler AP",
                zone_id="classrooms",
                lat=41.0088,
                lng=29.0130,
                map_x=0.58,
                map_y=0.68,
                capacity=160,
            ),
            AccessPoint(
                id=4,
                name="Spor Salonu AP",
                zone_id="sports",
                lat=41.0095,
                lng=29.0095,
                map_x=0.20,
                map_y=0.70,
                capacity=70,
            ),
        ]
        self._zone_names = {
            "library": "Kutuphane",
            "cafeteria": "Kafeterya",
            "classrooms": "Derslikler",
            "sports": "Spor Salonu",
        }
        self._device_counts = {ap.id: random.randint(8, ap.capacity // 2) for ap in self._access_points}
        self._signal_strength = {ap.id: random.randint(-78, -42) for ap in self._access_points}

    def access_points(self) -> list[AccessPoint]:
        return self._access_points

    def register_connection(self, event: ConnectionEvent) -> DensitySnapshot:
        self._find_access_point(event.ap_id)
        self._device_counts[event.ap_id] = min(self._device_counts[event.ap_id] + 1, 999)
        self._signal_strength[event.ap_id] = event.signal_strength
        return self.snapshot()

    def simulate_tick(self) -> DensitySnapshot:
        for ap in self._access_points:
            delta = random.randint(-5, 7)
            self._device_counts[ap.id] = max(0, min(ap.capacity + 30, self._device_counts[ap.id] + delta))
            self._signal_strength[ap.id] = random.randint(-84, -36)
        return self.snapshot()

    def snapshot(self) -> DensitySnapshot:
        zones = [self._zone_density(ap) for ap in self._access_points]
        return DensitySnapshot(
            campus="Demo Kampus",
            updated_at=datetime.now(timezone.utc).isoformat(),
            total_devices=sum(zone.device_count for zone in zones),
            zones=zones,
        )

    def _zone_density(self, ap: AccessPoint) -> ZoneDensity:
        device_count = self._device_counts[ap.id]
        density = max(0, min(100, round((device_count / ap.capacity) * 100)))
        return ZoneDensity(
            zone_id=ap.zone_id,
            zone_name=self._zone_names[ap.zone_id],
            ap_id=ap.id,
            ap_name=ap.name,
            device_count=device_count,
            density=density,
            signal_strength=self._signal_strength[ap.id],
            map_x=ap.map_x,
            map_y=ap.map_y,
            status=self._status_for(density),
        )

    def _find_access_point(self, ap_id: int) -> AccessPoint:
        for ap in self._access_points:
            if ap.id == ap_id:
                return ap
        raise ValueError(f"Access point not found: {ap_id}")

    @staticmethod
    def _status_for(density: int) -> str:
        if density >= 75:
            return "high"
        if density >= 45:
            return "medium"
        return "low"
