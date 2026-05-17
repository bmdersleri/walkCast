# walkCast

walkCast is a self-hosted workflow that captures video URLs, extracts MP3 audio in the background, and provides a mobile-first listening experience.

## Current Feature Set

- Save URLs from Chrome extension (active tab capture)
- Background extraction pipeline with `yt-dlp` + FFmpeg
- Item lifecycle statuses: `queued`, `downloading`, `converting_mp3`, `ready`, `error`
- File metadata tracking: title, duration, file path, file size
- Mobile PWA features:
  - Playlist cards with title, duration, size, and status
  - Playback speed control (`1.0x` to `2.0x`)
  - Optional auto-play next ready track
  - Drag-and-drop local ordering
  - Delete confirmation for server cleanup
  - Download, save offline, and play offline controls
- Chrome extension popup features:
  - Compact card layout with icon actions
  - Item status/size visibility
  - Up/down ordering controls
  - Delete action

## Repository Structure

- `backend/` FastAPI API, database models, worker, tests
- `mobile-pwa/` mobile web interface
- `extension/` Chrome extension popup
- `backend/storage/audio/` generated audio files (ignored in Git)

## Requirements

- Python 3.14+
- FFmpeg installed on host machine
- Optional: `aria2c` for faster downloads

## Installation

```bash
git clone https://github.com/bmdersleri/walkCast.git
cd walkCast
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run the Backend

```bash
uvicorn backend.app.main:app --reload
```

Useful endpoints:

- Base API: `http://127.0.0.1:8000/api/v1`
- Health: `http://127.0.0.1:8000/health`
- Audio static path: `/backend/storage/audio/...`

## API Quick Reference

- `POST /api/v1/items` — create item from URL
- `GET /api/v1/items` — list items
- `GET /api/v1/items/{id}` — get item by id
- `POST /api/v1/items/{id}/listen` — mark as listened
- `DELETE /api/v1/items/{id}` — delete DB record + physical file

Example create request:

```bash
curl -X POST http://127.0.0.1:8000/api/v1/items \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.youtube.com/watch?v=upshdP-1K_0"}'
```

## Mobile PWA Usage

1. Start backend.
2. Serve/open `mobile-pwa` (for example with `python3 -m http.server`).
3. Add URL with `Save URL`.
4. Wait until status is `Ready`.
5. Play, control speed, and optionally auto-play next track.
6. Use `Save Offline` to cache locally and `Play Offline` to play cached copy.
7. Use `Delete` for server cleanup (with confirmation).

## Chrome Extension Usage

1. Open `chrome://extensions/`.
2. Enable Developer mode.
3. Click **Load unpacked** and select `extension/`.
4. Open popup and verify API base URL.
5. Use icon actions:
   - `＋` save active tab
   - `↻` refresh list
   - `↑ / ↓` reorder items locally
   - `🗑` delete item

## Testing

Run backend smoke test:

```bash
PYTHONPATH=$(pwd) pytest -q backend/tests/test_items_api.py
```

Expected output:

- `1 passed`

## Notes

- The test flow uses a special `example.com` fast path in the downloader to avoid network/ffmpeg dependency during smoke tests.
- Local artifacts such as `backend/storage/` and prototype scripts are excluded via `.gitignore`.
