# TASKS.md — walkCast Implementation Backlog

## Phase 1 — Backend & Database Refactoring
Goal: Prepare the database schema for automated extraction.
- [ ] Add `duration` (String) and `is_listened` (Boolean, default False) to `Item` model.
- [ ] Update `status` Enum to include: `queued`, `downloading`, `converting_mp3`, `ready`, `error`.
- [ ] Generate and apply Alembic migration for the schema changes.

## Phase 2 — yt-dlp Background Worker
Goal: Integrate `mp3.py` logic into FastAPI.
- [ ] Move `yt-dlp` download logic into `backend/app/workers/downloader.py`.
- [ ] Implement `extract_info` to save Title and Duration to the database before downloading.
- [ ] Implement `progress_hooks` to update item `status` (downloading, converting, ready) in the database.
- [ ] Refactor `POST /api/v1/items` to accept a URL and trigger the worker via FastAPI `BackgroundTasks`.

## Phase 3 — Listen & Delete Workflow (Backend)
Goal: API endpoints for cleanup and tracking.
- [ ] Create `POST /api/v1/items/{id}/listen` endpoint to mark `is_listened = True`.
- [ ] Update `DELETE /api/v1/items/{id}` endpoint to use `os.remove()` to delete the physical MP3 file from `storage/audio/` before deleting the database record.

## Phase 4 — Mobile PWA Polish
Goal: Expose new metadata and cleanup features to the user on mobile.
- [ ] Update `ItemCard` component to display `title` and `duration` (e.g., 14:05).
- [ ] Add visual badges for processing statuses (Downloading, Converting, Ready).
- [ ] Implement HTML5 audio `onended` event listener.
- [ ] Trigger the `/listen` API call when audio finishes.
- [ ] Show a confirmation dialog after audio finishes: "Delete from server?". If yes, call `DELETE` API.

## Phase 5 — Chrome Extension Updates
Goal: Make the extension a mini-management dashboard.
- [ ] Update popup UI to show Item Titles, Durations, and Statuses instead of just URLs.
- [ ] Add a "Delete" (Trash) button next to each item in the extension to trigger the backend `DELETE` endpoint.

## Phase 6 — Testing & Deployment
- [ ] Test the full pipeline: Save via Extension -> Observe Download -> Play in PWA -> Auto-Delete.
- [ ] Ensure `yt-dlp` and `ffmpeg` are properly installed in the deployment environment (Ubuntu/Systemd).