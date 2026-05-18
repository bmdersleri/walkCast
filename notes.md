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
