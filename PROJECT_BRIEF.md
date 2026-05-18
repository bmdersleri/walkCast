# walkCast — Project Brief

## Project Identity

| Item | Value |
|---|---|
| Project name | walkCast |
| Repository | `https://github.com/bmdersleri/walkCast.git` |
| Product direction | Self-hosted backend + Chrome extension + native Flutter mobile app |
| Target users | Students, researchers, professionals learning on the go |
| Deployment target | Linux self-hosted backend, Android/iOS clients |

## Problem Statement

Users discover long-form educational videos on desktop but want to consume the content as clean audio while walking, commuting, or exercising. Existing flows are fragmented and require multiple manual steps.

walkCast unifies this flow:

1. Save source URL from Chrome extension.
2. Backend downloads and converts to MP3 in background.
3. User listens from mobile app, manages queue, and cleans up storage.

## Product Vision

`Discover -> Save URL -> Convert Automatically -> Listen Anywhere -> Manage Storage`

## Why Flutter Now

The PWA proved the workflow. Flutter is the scale step for:

- better offline reliability
- stronger playback/background behavior
- smoother list interactions on low-end phones
- consistent native UX for Android/iOS

## Core Use Cases

- `UC-01` Save active tab to queue from extension.
- `UC-02` Track backend status (`queued`, `downloading`, `converting_mp3`, `ready`, `error`).
- `UC-03` Listen with speed control and optional autoplay-next.
- `UC-04` Save tracks offline and replay without network.
- `UC-05` Delete server and local files intentionally with confirmation.
- `UC-06` Manage playlists and queue ordering.

## Success Metrics

- Time to first playable track (from URL save)
- Offline playback success rate
- Queue action completion rate (delete, reorder, move playlist)
- Crash-free sessions in beta

## Constraints and Assumptions

- No paid third-party API required for core workflow
- Host machine provides `yt-dlp` + `ffmpeg`
- Backend remains source of truth for remote queue state
- Flutter app keeps local cache for offline and fast rendering
