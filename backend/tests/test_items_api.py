from pathlib import Path
from uuid import uuid4

from fastapi.testclient import TestClient

from backend.app.db.database import SessionLocal
from backend.app.db.models import Item, ItemStatus
from backend.app.main import app


client = TestClient(app)


def test_create_listen_delete_item_flow():
    create_resp = client.post(
        "/api/v1/items",
        json={"url": "https://example.com/video", "playlist_id": 1, "audio_quality": "high"},
    )
    assert create_resp.status_code == 201
    payload = create_resp.json()
    item_id = payload["id"]
    assert payload["audio_quality"] == "high"

    get_resp = client.get(f"/api/v1/items/{item_id}")
    assert get_resp.status_code == 200

    listen_resp = client.post(f"/api/v1/items/{item_id}/listen")
    assert listen_resp.status_code == 200

    delete_resp = client.delete(f"/api/v1/items/{item_id}")
    assert delete_resp.status_code == 204

    get_after_delete = client.get(f"/api/v1/items/{item_id}")
    assert get_after_delete.status_code == 404

    fake_path = Path(f"backend/storage/audio/{item_id}.mp3")
    assert not fake_path.exists()


def test_audio_stream_supports_http_range():
    storage_dir = Path("backend/storage/audio")
    storage_dir.mkdir(parents=True, exist_ok=True)
    file_path = storage_dir / f"test-{uuid4().hex}.mp3"
    content = b"abcdefghijklmnopqrstuvwxyz0123456789"
    file_path.write_bytes(content)

    db = SessionLocal()
    item = Item(
        playlist_id=1,
        url="https://example.com/audio",
        status=ItemStatus.ready,
        filepath=str(file_path),
        file_size_bytes=len(content),
        audio_quality="medium",
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    item_id = item.id
    db.close()

    try:
        full_resp = client.get(f"/api/v1/items/{item_id}/audio")
        assert full_resp.status_code == 200
        assert full_resp.headers.get("accept-ranges") == "bytes"
        assert full_resp.content == content

        part_resp = client.get(
            f"/api/v1/items/{item_id}/audio",
            headers={"Range": "bytes=5-9"},
        )
        assert part_resp.status_code == 206
        assert part_resp.headers.get("content-range") == f"bytes 5-9/{len(content)}"
        assert part_resp.content == content[5:10]
    finally:
        db = SessionLocal()
        row = db.get(Item, item_id)
        if row:
            db.delete(row)
            db.commit()
        db.close()
        if file_path.exists():
            file_path.unlink()
