# walkCast

walkCast is a self-hosted workflow to save video URLs, extract audio as MP3 in the background, and consume it from mobile.

## Features

- Save video URL from Chrome Extension
- Background audio extraction with `yt-dlp` + FFmpeg flow
- Item lifecycle statuses: `queued`, `downloading`, `converting_mp3`, `ready`, `error`
- Mobile PWA list/play/listen/delete flow
- Server-side cleanup with physical file deletion

## Project Structure

- `backend/` FastAPI API + worker + tests
- `mobile-pwa/` lightweight mobile web UI
- `extension/` Chrome extension popup dashboard
- `backend/storage/audio/` generated audio files

## Requirements

- Python 3.14+
- FFmpeg installed on host
- (Optional but recommended) `aria2c`

## Setup

1. Clone and enter repository:

```bash
git clone https://github.com/bmdersleri/walkCast.git
cd walkCast
```

2. Create virtual environment and install dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run Backend

```bash
uvicorn backend.app.main:app --reload
```

- API base: `http://127.0.0.1:8000/api/v1`
- Health check: `http://127.0.0.1:8000/health`

## API Quick Reference

- `POST /api/v1/items` create item from URL
- `GET /api/v1/items` list items
- `GET /api/v1/items/{id}` get one item
- `POST /api/v1/items/{id}/listen` mark listened
- `DELETE /api/v1/items/{id}` delete DB record + file

Create sample item:

```bash
curl -X POST http://127.0.0.1:8000/api/v1/items \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.youtube.com/watch?v=upshdP-1K_0"}'
```

## Mobile PWA Usage

1. Start backend.
2. Open `mobile-pwa/index.html` in browser.
3. Paste URL and click `Save URL`.
4. Watch status badges until item becomes `Ready`.
5. Play audio; when playback ends, app calls `/listen` and asks for delete confirmation.

## Chrome Extension Usage

1. Open `chrome://extensions/`.
2. Enable **Developer mode**.
3. Click **Load unpacked** and select `extension/`.
4. Open extension popup.
5. Confirm API base (`http://127.0.0.1:8000/api/v1`).
6. Click `Save Active Tab` to send current URL.
7. Use `Delete` per item for cleanup.

## Tests

Run smoke test:

```bash
PYTHONPATH=$(pwd) pytest -q backend/tests/test_items_api.py
```

Expected result:

- `1 passed`

## Notes

- Current smoke test uses a test-only fast path in downloader for `example.com` URLs to avoid network/ffmpeg dependency in CI-like runs.
- Audio files are served from `/backend/storage/audio`.
