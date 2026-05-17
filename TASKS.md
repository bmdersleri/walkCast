# walkCast — Implementation Backlog

## Phase 1 — Backend and Database Foundation

Goal: Prepare schema and status model for background extraction.

- [x] Add `duration` and `is_listened` fields to `Item` model.
- [x] Align `status` enum with workflow states.
- [x] Add lightweight migration path for schema evolution.

## Phase 2 — Background Worker Integration

Goal: Integrate MP3 extraction flow into FastAPI backend.

- [x] Implement worker in `backend/app/workers/downloader.py`.
- [x] Save metadata (`title`, `duration`) before download.
- [x] Update progress statuses via hooks.
- [x] Trigger worker from `POST /api/v1/items` using `BackgroundTasks`.

## Phase 3 — Listen and Delete Workflow (Backend)

Goal: Add API operations for tracking and cleanup.

- [x] Implement `POST /api/v1/items/{id}/listen`.
- [x] Implement `DELETE /api/v1/items/{id}` with physical file deletion.
- [x] Add item list endpoint `GET /api/v1/items`.

## Phase 4 — Mobile PWA Enhancements

Goal: Provide practical mobile listening and cleanup experience.

- [x] Show title, duration, status badges in item cards.
- [x] Handle `audio.onended` and trigger listen update.
- [x] Ask for delete confirmation.
- [x] Add drag-and-drop playlist ordering.
- [x] Add playback speed controls (`1.0x`–`2.0x`).
- [x] Add optional auto-play next behavior.
- [x] Add `Download`, `Save Offline`, and `Play Offline` controls.
- [x] Add offline-state visual feedback (`Offline Saved`).

## Phase 5 — Chrome Extension Enhancements

Goal: Turn extension popup into a compact management dashboard.

- [x] Show title, duration, size, and status in compact cards.
- [x] Add item delete action.
- [x] Add icon-based controls for compact UI.
- [x] Add `up/down` ordering controls with persistent local order.

## Phase 6 — Testing and Readiness

- [x] Add API smoke test for `create -> listen -> delete` flow.
- [x] Run smoke test successfully in local environment.
- [ ] Add UI-level automated tests for PWA and extension.
- [ ] Validate ffmpeg/yt-dlp/aria2c availability in deployment profile.

## Next Candidate Tasks

- [ ] Persist playlist order server-side (shared across extension and PWA).
- [ ] Add pagination/filter/search for large queues.
- [ ] Add richer offline media management (delete local copy, usage stats).
- [ ] Add authentication and authorization for multi-user scenarios.
