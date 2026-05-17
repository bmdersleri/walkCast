# walkCast — Project Brief

## Project Identity

| Item | Value |
|---|---|
| Project name | walkCast |
| Repository | `https://github.com/bmdersleri/walkCast.git` |
| Tagline | Save videos now, listen later automatically. |
| Short description | A self-hosted system that turns saved video URLs into MP3 tracks for mobile listening. |
| Primary owner | Repository maintainer |
| Target users | Students, academics, researchers, lifelong learners |
| Deployment target | Self-hosted Ubuntu/Linux server |

## Problem Statement

Educational content is often discovered on desktop but consumed later on mobile while walking or commuting. Existing tools usually require manual steps such as downloading, transferring files, or keeping video apps open.

walkCast solves this with an automated flow:

1. Capture video URLs from a Chrome extension.
2. Extract and convert audio on a self-hosted backend using `yt-dlp` and FFmpeg.
3. Consume tracks in a mobile web UI with cleanup and offline-friendly controls.

## Vision

`Discover video -> Save from Extension -> Backend downloads/converts -> Listen on mobile -> Cleanup`

## Core Use Cases

- `UC-01` Save active browser tab to a listening queue.
- `UC-02` Automatically process saved URL in the background and track status.
- `UC-03` Listen from mobile web UI, control playback speed, and continue with next item based on user preference.
- `UC-04` Delete server files after listening to keep storage under control.
- `UC-05` Save tracks for offline playback on mobile.

## Product Principles

1. Privacy-first self-hosted architecture.
2. Minimal manual operations; background automation by default.
3. Storage-conscious lifecycle (listen, then delete if desired).
4. Mobile-first listening experience.
5. Explicit user control for destructive actions.
