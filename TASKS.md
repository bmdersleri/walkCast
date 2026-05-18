# walkCast — Implementation Backlog

## Phase A — Planning and Contract Freeze

- [ ] Finalize Flutter parity scope against PWA
- [ ] Freeze API payload contract for Flutter
- [ ] Decide local DB choice (`isar` primary, `hive` fallback)
- [ ] Define quality mapping and defaults (`good`, `medium`, `high`)

## Phase B — Flutter Project Bootstrap

- [x] Create `apps/walkcast_mobile` with flavor-ready structure
- [x] Add dependencies (`riverpod`, `dio`, `just_audio`, `audio_service`, `isar/hive`, `path_provider`)
- [x] Setup linting, formatting, and CI test command
- [x] Configure environment handling for API base URL

## Phase C — Data and Domain Layer

- [x] Implement API client and typed DTO models
- [x] Build repository layer with error mapping
- [x] Add polling strategy for item status updates
- [x] Implement local storage schema for offline files and preferences

## Phase D — Core UI and Playback

- [x] Build queue list screen with card states (status/size/progress/ETA)
- [x] Build add URL flow with playlist + quality controls
- [x] Build player controls (play/pause, speed, autoplay-next)
- [x] Handle listen-complete event and backend sync

## Phase E — Offline and Playlist Management

- [ ] Implement Save Offline download pipeline
- [ ] Add offline state styling and button state transitions
- [ ] Implement Play Offline with fallback logic
- [ ] Add local offline delete option
- [ ] Implement drag-and-drop reorder
- [ ] Implement playlist create/select/reassign flows

## Phase F — Extension and PWA Alignment

- [ ] Keep extension UX visually aligned with Flutter language
- [ ] Validate quality controls and playlist behavior in extension
- [ ] Keep PWA as fallback client until Flutter release

## Phase G — Testing and Release

- [ ] Unit tests for repositories and use cases
- [ ] Widget tests for queue cards and action states
- [ ] Integration tests for end-to-end playback flow
- [ ] Device QA checklist (Android first, then iOS)
- [ ] Internal beta build and feedback cycle

## Immediate Next 7 Tasks

- [x] Create Flutter app skeleton and baseline folders
- [x] Add API model for item including quality/size/progress fields
- [x] Build queue screen static prototype from current design language
- [x] Wire list fetch from backend and render live cards
- [x] Implement quality radio selector on add URL form
- [x] Implement offline save state toggle in UI
- [x] Add first widget test for card state rendering

## Recent Fixes

- [x] Keep active playing item at top of visible playlist.
- [x] Preserve track position across play/pause for same item.
- [x] Show elapsed and remaining time during playback.

## Maintenance

- [x] Remove tracked runtime artifacts (`venv/`, `.run/`) from git history tip.
- [x] Enforce ignore rules for local/runtime directories in `.gitignore`.

- [x] Fix: selected track play action now starts the tapped item (not first queue item).
- [x] Fix: seek-to-position now resumes from selected position reliably.

- [x] Fix: card tap now always plays selected item (prevents stale first-track playback).
- [x] Fix: seek end now applies only to currently loaded item and persists position.

- [x] Fix: active-card title/state now follows tapped track instantly.
- [x] Fix: seek fallback reload added for servers not honoring range-seek consistently.
- [x] UX: playing item cover rotation animation added.

- [x] Backend: add item audio stream endpoint with Range support.
- [x] Mobile: route playback through `/api/v1/items/{id}/audio`.
- [x] Mobile: unify seek/ff/rewind with verified seek + reload fallback.
- [x] Backend test: HTTP range response validation.

- [x] Compatibility fix: mobile player fallback URL chain for mixed backend deployments.

- [x] Fix: playing item is moved to top in source list for stable card binding.
- [x] Fix: active card progress/time binding now follows `_playingItemId` directly.

- [x] Fix: autoplay-next strictly gated by play mode = `all`.
- [x] Default play mode changed to `track by track`.

- [x] UX: active play control LED indicator (blue blink on play, yellow on pause).

- [x] Fix: switching tracks now clears stale seek state and prevents frozen slider/counters.

- [x] Feature: settings screen for server host and port.
- [x] Feature: auto-save host/port changes.
- [x] Refactor: API client now resolves base URL dynamically per request.

- [x] Tooling: add git reset helper script for soft/hard reset workflows.
- [x] Tooling: add Flutter reset helper script (`soft` hot reload, `hard` hot restart).

- [x] Fix: prevent stale duration/position values from previous source during track switch.
- [x] UX: keep active slider visible even before duration arrives.

- [x] Fix: track-by-track mode no longer auto-advances after manual stop/pause.
