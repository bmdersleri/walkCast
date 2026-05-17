# walkCast Notes

This file captures implementation notes that influenced the current backend and UI behavior.

## Metadata Before Download

`yt-dlp` supports metadata extraction without downloading media:

```python
info = ydl.extract_info(url, download=False)
```

This is used to populate:

- `title`
- `duration`

before the actual download starts.

## Duration Formatting

Duration is normalized for display as `MM:SS`:

```python
minutes, seconds = divmod(duration_seconds, 60)
formatted = f"{minutes}:{seconds:02d}"
```

## Status Lifecycle

Current item lifecycle:

- `queued`
- `downloading`
- `converting_mp3`
- `ready`
- `error`

The worker updates status using yt-dlp progress hooks.

## File Size Handling

File size is stored in `file_size_bytes` when the output file is produced.

A route-level fallback also computes size from disk when older records do not yet have a stored size.

## Mobile UX Decisions

Implemented UX choices:

- Explicit confirmation before server-side delete.
- Offline state should be visible (`Offline Saved` button style).
- Playlist ordering is user-controlled.
- Playback behavior should remain user-configurable (speed and auto-next).

## Extension UX Decisions

The popup was compacted for high-density usage:

- Smaller cards and badges.
- Icon-based actions.
- Up/down controls for local ordering.
