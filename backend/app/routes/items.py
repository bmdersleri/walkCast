from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Response
from sqlalchemy.orm import Session

from backend.app.db.database import get_db
from backend.app.db.models import Item, ItemStatus
from backend.app.schemas.items import ItemCreate, ItemCreateResponse
from backend.app.workers.downloader import download_audio

router = APIRouter(prefix="/api/v1/items", tags=["items"])


def _to_response(item: Item) -> ItemCreateResponse:
    return ItemCreateResponse(
        id=item.id,
        status=item.status.value,
        title=item.title,
        duration=item.duration,
        is_listened=item.is_listened,
        filepath=item.filepath,
        file_size_bytes=item.file_size_bytes,
    )


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

    return _to_response(item)


@router.get("", response_model=list[ItemCreateResponse])
def list_items(db: Session = Depends(get_db)):
    items = db.query(Item).order_by(Item.created_at.desc()).all()
    return [_to_response(item) for item in items]


@router.get("/{item_id}", response_model=ItemCreateResponse)
def get_item(item_id: int, db: Session = Depends(get_db)):
    item = db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    return _to_response(item)


@router.post("/{item_id}/listen", response_model=ItemCreateResponse)
def mark_item_listened(item_id: int, db: Session = Depends(get_db)):
    item = db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    item.is_listened = True
    db.commit()
    db.refresh(item)
    return _to_response(item)


@router.delete("/{item_id}", status_code=204, response_class=Response)
def delete_item(item_id: int, db: Session = Depends(get_db)):
    item = db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    if item.filepath:
        file_path = Path(item.filepath)
        if file_path.exists() and file_path.is_file():
            file_path.unlink()

    db.delete(item)
    db.commit()
    return Response(status_code=204)
