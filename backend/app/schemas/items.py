from datetime import datetime
from typing import Literal

from pydantic import BaseModel, HttpUrl


class ItemCreate(BaseModel):
    url: HttpUrl
    playlist_id: int | None = None
    audio_quality: Literal["good", "medium", "high"] = "medium"


class ItemCreateResponse(BaseModel):
    id: int
    playlist_id: int | None = None
    audio_quality: Literal["good", "medium", "high"] = "medium"
    status: str
    title: str | None = None
    duration: str | None = None
    is_listened: bool = False
    filepath: str | None = None
    file_size_bytes: int | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class ItemUpdatePlaylist(BaseModel):
    playlist_id: int
