# walkCast Notes

## Decision Log

- Mobile PWA validated product-market workflow and remains fallback web client.
- Flutter becomes primary mobile client for better offline playback and native UX.
- Backend stays source of truth for remote queue and conversion statuses.
- Audio quality options are standardized as `good`, `medium`, `high`.
- Repository hygiene is strict: local runtime artifacts (`venv/`, `.run/`) stay untracked.
- Playback continuity is mandatory: seek and pause/resume must continue from current position.
- Active playing item should be visually and positionally prioritized in list rendering.

## Technical Direction

- Backend: FastAPI + background worker (`yt-dlp` + ffmpeg)
- Mobile app: Flutter (`riverpod`, `dio`, `just_audio`, local DB)
- Extension: lightweight queue capture/control companion

## Risk Watchlist

- FFmpeg/yt-dlp availability on host environments
- Progress + ETA consistency from worker to UI
- Offline file lifecycle sync (server copy vs local copy)
- Cross-client order/playlist consistency (extension, PWA, Flutter)

## Near-Term Priorities

1. Add playlist-level play actions (`play all`, `track by track`) and verify completion flow.
2. Expand widget tests for playback state transitions and seek persistence.
3. Add integration test for mobile queue ordering (active item pinned on top).
4. Keep PWA/extension behavior aligned with Flutter UX decisions.

- Fixed mobile playback selection bug: tapping a track now starts that exact track and pins it to top immediately.
- Fixed seek persistence bug: seeking within current track no longer falls back to the start on resume.

- Added stable item keys in Flutter queue list to keep card/slider bindings correct during active-item reordering.

- Added seek fallback strategy (reload with initialPosition) to handle non-ideal HTTP range behavior.

- Root cause for seek drift was static-file playback inconsistency under some web/runtime combinations; fixed by item-scoped range endpoint + client fallback.

- Added backward-compatible audio source fallback to avoid hard dependency on newly deployed stream endpoint.

- Replaced visual-only top pinning with source-list promotion on play to prevent stale card title/progress rendering after reorder.

- Hardened play mode parsing with explicit enum-like constants (`all` / `single`) and fallback to `single` for unknown stored values.

- Added active playback LED state to queue card actions for immediate play/pause feedback.

- Duration stream now accepts null->zero transition to avoid carrying stale duration to newly selected track.

- Runtime API target is now user-configurable via Hive-backed settings (host + port), removing hard dependency on build-time dart-define for daily use.

- Added `scripts/git-reset.sh` for consistent local soft/hard reset operations with a default target (`origin/main`).
- Clarified reset semantics: in project workflow, Flutter soft/hard reset is now handled by `scripts/flutter-reset.sh` (`r`/`R`), separate from git reset operations.

- Added source-switch guard: stream updates are ignored while no loaded item is set, eliminating frozen/mismatched top-card timer artifacts.

- Added completion guard: auto-advance now requires natural end threshold and is suppressed after user pause actions.

- Added render-level active pinning in `_visibleItems()` to prevent stale previous-title top-card scenarios.

- Added `_allowAutoAdvance` runtime gate to eliminate accidental next-track transitions when mode is `single`.

- Introduced `_sequenceItems()` (canonical order) vs `_visibleItems()` (UI-pinned order) split to prevent next-track regression.

- Top card now provides explicit adjacent-track navigation (`skip_previous` / `skip_next`) using ready-track sequence order.

- Consolidated card actions: top-card-only seek controls and icon-based downloaded state improve scanability and reduce button clutter.
- Adopted local-first playback strategy for mobile:
  - local cache is preferred when available
  - first play triggers background auto-download for future local playback
- Added download observability:
  - live per-item progress
  - ETA derived from measured transfer speed
  - playlist-wide sequential download queue progress in top panel
- Added strict auto-advance guards:
  - user-triggered pause/stop sets a short manual-stop guard window to suppress completion race auto-next
  - auto-next candidate list now excludes both server-listened and already-completed tracks
- Downloader selection policy changed from best-audio-first to smallest-audio-first (`worstaudio` + sort by bitrate/size asc) to reduce ingest bandwidth and conversion latency.
