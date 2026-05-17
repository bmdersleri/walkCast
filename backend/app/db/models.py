import enum
from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, Enum, DateTime
from sqlalchemy.sql import func
from .database import Base # Projenizdeki base importuna göre ayarlayın

class ItemStatus(str, enum.Enum):
    saved = "saved"
    queued = "queued"
    downloading = "downloading"
    converting_mp3 = "converting_mp3"
    ready = "ready"
    error = "error"
    archived = "archived"

class Item(Base):
    __tablename__ = "items"

    id = Column(Integer, primary_key=True, index=True)
    playlist_id = Column(Integer, index=True) # ForeignKey("playlists.id") projenize göre ayarlayın
    url = Column(String, index=True, nullable=False)
    
    # Yeni Eklenen / Güncellenen Alanlar
    title = Column(String, nullable=True)
    duration = Column(String, nullable=True)
    status = Column(Enum(ItemStatus), default=ItemStatus.queued)
    is_listened = Column(Boolean, default=False)
    filepath = Column(String, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())