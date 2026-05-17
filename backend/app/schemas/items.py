from pydantic import BaseModel, HttpUrl


class ItemCreate(BaseModel):
    url: HttpUrl
    playlist_id: int | None = None


class ItemCreateResponse(BaseModel):
    id: int
    status: str
    title: str | None = None
    duration: str | None = None
