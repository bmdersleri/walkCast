# walkCast Notes

## Decision Log

- Mobile PWA validated product-market workflow and remains fallback web client.
- Flutter becomes primary mobile client for better offline playback and native UX.
- Backend stays source of truth for remote queue and conversion statuses.
- Audio quality options are standardized as `good`, `medium`, `high`.
- Repository hygiene is strict: local runtime artifacts (`venv/`, `.run/`) stay untracked.

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

1. Bootstrap Flutter app structure.
2. Implement typed API + queue list rendering.
3. Implement offline save/play with clear visual states.
4. Add widget and integration test baseline.
