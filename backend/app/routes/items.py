from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy.orm import Session

from backend.app.db.database import get_db
from backend.app.db.models import Item, ItemStatus
from backend.app.schemas.items import ItemCreate, ItemCreateResponse
from backend.app.workers.downloader import download_audio

router = APIRouter(prefix="/api/v1/items", tags=["items"])


@router.post("", response_model=ItemCreateResponse, status_code=201)
def create_item(payload: ItemCreate, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    item = Item(
        playlist_id=payload.playlist_id,
        url=str(payload.url),
        status=ItemStatus.queued,
    )
    db.add(item)
    db.commit()
    db.refresh(item)

    background_tasks.add_task(download_audio, item.id, str(payload.url))

    return ItemCreateResponse(id=item.id, status=item.status.value, title=item.title, duration=item.duration)


@router.get("/{item_id}", response_model=ItemCreateResponse)
def get_item(item_id: int, db: Session = Depends(get_db)):
    item = db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    return ItemCreateResponse(id=item.id, status=item.status.value, title=item.title, duration=item.duration)
