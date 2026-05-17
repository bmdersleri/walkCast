from pathlib import Path

from fastapi.testclient import TestClient

from backend.app.main import app


client = TestClient(app)


def test_create_listen_delete_item_flow():
    create_resp = client.post("/api/v1/items", json={"url": "https://example.com/video", "playlist_id": 1})
    assert create_resp.status_code == 201
    payload = create_resp.json()
    item_id = payload["id"]

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
