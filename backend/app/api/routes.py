from fastapi import APIRouter, HTTPException

from app.models.schemas import AccessPoint, ConnectionEvent, DensitySnapshot
from app.services.density_service import DensityService


def build_router(density_service: DensityService) -> APIRouter:
    router = APIRouter()

    @router.get("/")
    def home() -> dict[str, str]:
        return {"message": "Campus Density Backend is running"}

    @router.get("/access-points", response_model=list[AccessPoint])
    def get_access_points() -> list[AccessPoint]:
        return density_service.access_points()

    @router.get("/density", response_model=DensitySnapshot)
    def get_density() -> DensitySnapshot:
        return density_service.snapshot()

    @router.post("/connections", response_model=DensitySnapshot)
    def create_connection(event: ConnectionEvent) -> DensitySnapshot:
        try:
            return density_service.register_connection(event)
        except ValueError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    @router.post("/simulate", response_model=DensitySnapshot)
    def simulate_density() -> DensitySnapshot:
        return density_service.simulate_tick()

    return router
