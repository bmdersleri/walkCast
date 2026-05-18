import enum
from sqlalchemy import Column, Integer, String, Boolean, Enum, DateTime
from sqlalchemy.sql import func
from .database import Base


class ItemStatus(str, enum.Enum):
    queued = "queued"
    downloading = "downloading"
    converting_mp3 = "converting_mp3"
    ready = "ready"
    error = "error"


class Item(Base):
    __tablename__ = "items"

    id = Column(Integer, primary_key=True, index=True)
    playlist_id = Column(Integer, index=True)
    url = Column(String, index=True, nullable=False)

    title = Column(String, nullable=True)
    duration = Column(String, nullable=True)
    status = Column(Enum(ItemStatus, name="item_status"), default=ItemStatus.queued, nullable=False)
    is_listened = Column(Boolean, default=False, nullable=False)
    filepath = Column(String, nullable=True)
    file_size_bytes = Column(Integer, nullable=True)
    audio_quality = Column(String, nullable=False, default="medium")

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
