# walkCast

walkCast is a self-hosted "save video now, listen later" system. The current product includes a FastAPI backend, a mobile PWA, and a Chrome extension. The next major step is a full Flutter mobile app that keeps the same workflow while improving performance, offline control, and native UX.

## Current Scope

- Backend API (`FastAPI`) with background download + MP3 conversion pipeline
- Mobile PWA for playlist playback and cleanup
- Chrome extension popup for saving URLs and queue management
- Local storage lifecycle: convert -> listen -> delete

## Flutter Mobile App Plan (Complete)

### Phase 0 - Alignment and Baseline (1-2 days)

- Freeze feature parity target with PWA:
  - playlist listing
  - playback speed (`1.0x`-`2.0x`)
  - autoplay-next toggle
  - delete confirmation
  - offline save/play
  - file size/status visibility
- Confirm backend contract fields:
  - `status`, `file_size_bytes`, `audio_quality`, `duration`, `filepath`
  - progress and ETA behavior for mobile UX
- Define success criteria:
  - first playable track time
  - offline save success rate
  - crash-free test sessions

### Phase 1 - Flutter Foundation (2-3 days)

- Create app module: `apps/walkcast_mobile`
- Core stack:
  - state: `riverpod`
  - networking: `dio`
  - audio: `just_audio`, `audio_service`
  - local db: `isar` (or `hive` fallback)
  - file paths: `path_provider`
  - downloads: `dio` with progress callbacks
- App architecture:
  - `data/` (api + dto + repo)
  - `domain/` (entities + usecases)
  - `presentation/` (screens/widgets/controllers)

### Phase 2 - API and Data Layer (2-3 days)

- Implement typed API client:
  - `POST /api/v1/items`
  - `GET /api/v1/items`
  - `GET /api/v1/items/{id}`
  - `POST /api/v1/items/{id}/listen`
  - `DELETE /api/v1/items/{id}`
  - `PATCH /api/v1/items/{id}` (playlist/order/quality updates if enabled)
- Add robust error mapping:
  - network unavailable
  - backend unavailable
  - conversion failed
- Add polling strategy for queue updates (interval + backoff)

### Phase 3 - Core Screens (4-5 days)

- Queue screen
  - modern compact cards
  - status badge, duration, file size, progress, ETA
  - offline-saved visual state
- Add URL flow
  - URL input
  - quality selector (`Good`, `Medium`, `High`)
  - optional playlist chooser
- Player controls
  - play/pause
  - speed control
  - autoplay-next preference
  - mark listened on end

### Phase 4 - Offline and File Management (3-4 days)

- Save Offline action:
  - download MP3 to app sandbox
  - persist local metadata (`local_path`, `saved_at`, `size_bytes`)
  - switch button style/state after save
- Play Offline action:
  - play local file when available
  - fallback to remote stream if local copy missing
- Offline housekeeping:
  - remove local copy
  - show local storage usage summary

### Phase 5 - Playlist UX and Advanced Controls (2-3 days)

- Drag-and-drop playlist reordering
- Multiple playlists (create, rename, assign, move)
- Delete confirmation modal for destructive actions
- Sync preferences across sessions (speed, autoplay-next, selected quality)

### Phase 6 - Reliability, QA, and Release Prep (3-5 days)

- Testing matrix:
  - unit tests for repositories/usecases
  - widget tests for cards/actions/state changes
  - integration tests for full add -> ready -> play -> delete flow
- Real-device checks:
  - Android first, then iOS
  - lock-screen/background playback behavior
  - airplane mode offline playback
- Release readiness:
  - app icon/splash
  - telemetry/logging hooks
  - internal beta distribution

## Test Procedure (Recommended)

```bash
cd /home/haytekllm/projects/walkcast-clean
source .venv/bin/activate
./scripts/dev-servers.sh restart
./scripts/dev-servers.sh status
pytest -q backend/tests/test_items_api.py
```

## Repo Structure

- `backend/` API, models, worker, tests
- `mobile-pwa/` existing web-mobile interface
- `extension/` Chrome extension popup
- `scripts/dev-servers.sh` local start/stop/restart helper

## Repository Hygiene

- Runtime and machine-local files are never committed.
- Ignored paths include `.venv/`, `venv/`, `.run/`, `__pycache__/`, `.pytest_cache/`, `node_modules/`, and `*.db`.
- Keep commits focused on source code, configuration, and documentation only.

## Next Delivery Milestone

M1 target: Flutter MVP with parity for queue list, playback controls, delete confirmation, and offline save/play on Android.

## Latest Update (2026-05-18)

- Fixed playback resume/seek continuity bug:
  - pressing play again on a paused track now resumes from the same position
  - seek slider no longer resets playback to start on play/pause transitions
- Active playing item is pinned to top of the visible playlist in mobile UI.
- Now shows elapsed and remaining time together while a track is playing.
- Validation:
  - `flutter analyze` passed
  - `flutter test` passed

- Bugfix: Mobile player now tracks loaded item identity to avoid wrong-track autoplay and unwanted reset after seek.

- Fixed strict loaded-track playback flow: tapping a card now loads/plays that exact item, with stop->setUrl sequencing to avoid stale source playback.

- Playback UI sync fix: active card title now switches immediately to tapped track before load completes.
- Seek reliability improved with fallback reload at target position when remote seek is ignored.
- Playing card cover now rotates to provide live playback animation feedback.

- Added backend audio streaming endpoint with HTTP Range support: `GET /api/v1/items/{id}/audio` (206 partial content).
- Mobile player now uses item-scoped audio endpoint for stable seek/skip behavior.
