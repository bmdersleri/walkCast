from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, Response
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from backend.app.db.database import get_db
from backend.app.db.models import Item, ItemStatus
from backend.app.schemas.items import ItemCreate, ItemCreateResponse, ItemUpdatePlaylist
from backend.app.workers.downloader import download_audio

router = APIRouter(prefix="/api/v1/items", tags=["items"])


def _parse_range_header(range_header: str, file_size: int) -> tuple[int, int] | None:
    if not range_header.startswith("bytes="):
        return None
    range_value = range_header[6:].strip()
    if "," in range_value:
        return None

    start_str, sep, end_str = range_value.partition("-")
    if sep != "-":
        return None

    if start_str == "":
        try:
            suffix_length = int(end_str)
        except ValueError:
            return None
        if suffix_length <= 0:
            return None
        start = max(file_size - suffix_length, 0)
        end = file_size - 1
        return (start, end)

    try:
        start = int(start_str)
    except ValueError:
        return None

    if start < 0 or start >= file_size:
        return None

    if end_str == "":
        end = file_size - 1
    else:
        try:
            end = int(end_str)
        except ValueError:
            return None
        if end < start:
            return None
        end = min(end, file_size - 1)

    return (start, end)


def _resolve_file_size(item: Item, db: Session) -> int | None:
    if item.file_size_bytes is not None:
        return item.file_size_bytes

    if not item.filepath:
        return None

    file_path = Path(item.filepath)
    if not file_path.exists() or not file_path.is_file():
        return None

    size = file_path.stat().st_size
    item.file_size_bytes = size
    db.commit()
    return size


def _to_response(item: Item, db: Session) -> ItemCreateResponse:
    return ItemCreateResponse(
        id=item.id,
        playlist_id=item.playlist_id,
        audio_quality=item.audio_quality or "medium",
        status=item.status.value,
        title=item.title,
        duration=item.duration,
        is_listened=item.is_listened,
        filepath=item.filepath,
        file_size_bytes=_resolve_file_size(item, db),
        created_at=item.created_at,
        updated_at=item.updated_at,
    )


@router.post("", response_model=ItemCreateResponse, status_code=201)
def create_item(payload: ItemCreate, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    item = Item(
        playlist_id=payload.playlist_id,
        audio_quality=payload.audio_quality,
        url=str(payload.url),
        status=ItemStatus.queued,
    )
    db.add(item)
    db.commit()
    db.refresh(item)

    background_tasks.add_task(download_audio, item.id, str(payload.url))

    return _to_response(item, db)


@router.get("", response_model=list[ItemCreateResponse])
def list_items(db: Session = Depends(get_db)):
    items = db.query(Item).order_by(Item.created_at.desc()).all()
    return [_to_response(item, db) for item in items]


@router.get("/{item_id}", response_model=ItemCreateResponse)
def get_item(item_id: int, db: Session = Depends(get_db)):
    item = db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    return _to_response(item, db)


@router.post("/{item_id}/listen", response_model=ItemCreateResponse)
def mark_item_listened(item_id: int, db: Session = Depends(get_db)):
    item = db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    item.is_listened = True
    db.commit()
    db.refresh(item)
    return _to_response(item, db)


@router.patch("/{item_id}", response_model=ItemCreateResponse)
def update_item_playlist(item_id: int, payload: ItemUpdatePlaylist, db: Session = Depends(get_db)):
    item = db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    item.playlist_id = payload.playlist_id
    db.commit()
    db.refresh(item)
    return _to_response(item, db)


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


@router.get("/{item_id}/audio")
def stream_item_audio(item_id: int, request: Request, db: Session = Depends(get_db)):
    item = db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    if not item.filepath:
        raise HTTPException(status_code=404, detail="Audio file not found")

    file_path = Path(item.filepath)
    if not file_path.exists() or not file_path.is_file():
        raise HTTPException(status_code=404, detail="Audio file not found")

    file_size = file_path.stat().st_size
    mime = "audio/mpeg"
    range_header = request.headers.get("range")

    headers = {
        "Accept-Ranges": "bytes",
        "Content-Type": mime,
        "Cache-Control": "no-cache",
    }

    if not range_header:
        return StreamingResponse(
            file_path.open("rb"),
            media_type=mime,
            headers={**headers, "Content-Length": str(file_size)},
            status_code=200,
        )

    range_values = _parse_range_header(range_header, file_size)
    if range_values is None:
        return Response(status_code=416, headers={**headers, "Content-Range": f"bytes */{file_size}"})

    start, end = range_values
    chunk_size = end - start + 1

    def iter_file():
        with file_path.open("rb") as fh:
            fh.seek(start)
            remaining = chunk_size
            while remaining > 0:
                read_size = min(64 * 1024, remaining)
                data = fh.read(read_size)
                if not data:
                    break
                remaining -= len(data)
                yield data

    return StreamingResponse(
        iter_file(),
        media_type=mime,
        headers={
            **headers,
            "Content-Length": str(chunk_size),
            "Content-Range": f"bytes {start}-{end}/{file_size}",
        },
        status_code=206,
    )
