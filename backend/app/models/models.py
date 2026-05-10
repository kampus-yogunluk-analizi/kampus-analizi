from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime

Base = declarative_base()

class Building(Base):
    __tablename__ = "buildings"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True)
    latitude = Column(Float)
    longitude = Column(Float)

class DensityData(Base):
    __tablename__ = "density_data"
    
    id = Column(Integer, primary_key=True, index=True)
    building_id = Column(Integer, ForeignKey("buildings.id"))
    wifi_count = Column(Integer)      
    bluetooth_count = Column(Integer) 
    timestamp = Column(DateTime, default=datetime.utcnow)