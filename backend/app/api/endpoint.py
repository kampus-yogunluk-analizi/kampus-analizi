from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database.config import get_db  
from app.models.models import Building, DensityData 
router = APIRouter()


@router.get("/heatmap-data")
def get_heatmap_data(db: Session = Depends(get_db)):
    results = db.query(Building, DensityData).join(DensityData).all()
    
    heatmap_list = []
    for building, density in results:
        heatmap_list.append({
            "name": building.name,
            "lat": building.latitude,
            "lng": building.longitude,
            "intensity": (density.wifi_count + density.bluetooth_count)
        })
    return heatmap_list

@router.post("/update-density")
def update_density(building_id: int, wifi: int, bt: int, db: Session = Depends(get_db)):
    new_data = DensityData(
        building_id=building_id, 
        wifi_count=wifi, 
        bluetooth_count=bt
    )
    db.add(new_data)
    db.commit()
    return {"status": "success"}