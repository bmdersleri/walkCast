# walkCast — Product Requirements

## 1. Functional Requirements

### 1.1 Chrome Extension

| ID | Requirement | Priority |
|---|---|---|
| FR-EXT-001 | Capture active tab URL and send it to backend. | Must |
| FR-EXT-002 | Show item title, duration, size, and status in popup cards. | Must |
| FR-EXT-003 | Support item deletion from popup. | Must |
| FR-EXT-004 | Support local ordering controls (`up/down`) in popup. | Should |

### 1.2 Backend API and Database

| ID | Requirement | Priority |
|---|---|---|
| FR-API-001 | Accept URLs and trigger background extraction task. | Must |
| FR-API-002 | Store `title`, `duration`, `is_listened`, `status`, `filepath`, `file_size_bytes`. | Must |
| FR-API-003 | Track statuses: `queued`, `downloading`, `converting_mp3`, `ready`, `error`. | Must |
| FR-API-004 | `DELETE /api/v1/items/{id}` removes DB record and physical file. | Must |
| FR-API-005 | Serve generated audio files for playback/download. | Must |

### 1.3 Audio Processing Worker

| ID | Requirement | Priority |
|---|---|---|
| FR-AUD-001 | Use `yt-dlp` (+ optional `aria2c`) for extraction. | Must |
| FR-AUD-002 | Use FFmpeg post-processing to produce MP3. | Must |
| FR-AUD-003 | Update item status via progress hooks. | Must |
| FR-AUD-004 | Extract metadata (`title`, `duration`) before download. | Must |
| FR-AUD-005 | Persist resulting file size in bytes. | Must |

### 1.4 Mobile PWA

| ID | Requirement | Priority |
|---|---|---|
| FR-PWA-001 | List items with title, duration, size, and status badges. | Must |
| FR-PWA-002 | Play tracks using HTML5 audio. | Must |
| FR-PWA-003 | Mark listened on `audio.onended`. | Must |
| FR-PWA-004 | Show delete confirmation before server-side deletion. | Must |
| FR-PWA-005 | Reorder playlist with drag-and-drop. | Should |
| FR-PWA-006 | Support playback speed selection (`1.0x` to `2.0x`). | Should |
| FR-PWA-007 | Auto-play next ready track based on user preference. | Should |
| FR-PWA-008 | Allow download and offline local playback for saved tracks. | Should |

## 2. Non-Functional Requirements

| ID | Requirement | Target |
|---|---|---|
| NFR-001 | No paid external API dependency for core flow. | Mandatory |
| NFR-002 | Background tasks must not block HTTP request lifecycle. | Mandatory |
| NFR-003 | UI actions should remain responsive on low-end mobile devices. | Target |
| NFR-004 | Destructive actions require explicit user confirmation in mobile UI. | Mandatory |
