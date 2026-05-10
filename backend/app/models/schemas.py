from pydantic import BaseModel, Field


class AccessPoint(BaseModel):
    id: int
    name: str
    zone_id: str
    lat: float
    lng: float
    map_x: float = Field(ge=0, le=1)
    map_y: float = Field(ge=0, le=1)
    capacity: int


class ZoneDensity(BaseModel):
    zone_id: str
    zone_name: str
    ap_id: int
    ap_name: str
    device_count: int
    density: int = Field(ge=0, le=100)
    signal_strength: int
    map_x: float = Field(ge=0, le=1)
    map_y: float = Field(ge=0, le=1)
    status: str


class DensitySnapshot(BaseModel):
    campus: str
    updated_at: str
    total_devices: int
    zones: list[ZoneDensity]


class ConnectionEvent(BaseModel):
    ap_id: int
    device_id: str | None = None
    signal_strength: int = Field(default=-55, ge=-100, le=-20)
