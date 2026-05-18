# walkCast — Product Requirements

## 1. Functional Requirements

### 1.1 Backend and Processing

| ID | Requirement | Priority |
|---|---|---|
| FR-BE-001 | Accept URL and enqueue async processing. | Must |
| FR-BE-002 | Track item lifecycle: `queued`, `downloading`, `converting_mp3`, `ready`, `error`. | Must |
| FR-BE-003 | Persist metadata: title, duration, file path, file size, playlist, quality. | Must |
| FR-BE-004 | Expose progress and estimated remaining time for UI. | Should |
| FR-BE-005 | Delete item endpoint removes both DB record and physical file. | Must |

### 1.2 Chrome Extension

| ID | Requirement | Priority |
|---|---|---|
| FR-EXT-001 | Capture active tab URL and send to backend. | Must |
| FR-EXT-002 | Let user choose target playlist before save. | Should |
| FR-EXT-003 | Show compact cards with status, size, and action icons. | Must |
| FR-EXT-004 | Reorder items via up/down controls. | Should |
| FR-EXT-005 | Show backend connectivity status with icon. | Must |
| FR-EXT-006 | Show download/convert progress bar and ETA when available. | Should |
| FR-EXT-007 | Support quality choice (`good`, `medium`, `high`) as radio controls. | Must |

### 1.3 Flutter Mobile App

| ID | Requirement | Priority |
|---|---|---|
| FR-FL-001 | Display queue cards with title, duration, size, status, progress, ETA. | Must |
| FR-FL-002 | Support online playback and mark listened on track end. | Must |
| FR-FL-003 | Provide speed controls between `1.0x` and `2.0x`. | Must |
| FR-FL-004 | Provide autoplay-next as user preference. | Must |
| FR-FL-005 | Confirm destructive delete actions before execution. | Must |
| FR-FL-006 | Support drag-and-drop queue reorder. | Should |
| FR-FL-007 | Support multiple playlists and reassignment of items. | Should |
| FR-FL-008 | Save MP3 for offline use and indicate offline state visually. | Must |
| FR-FL-009 | Allow deleting local offline copy independently from server copy. | Should |
| FR-FL-010 | Provide quality selection during URL submission. | Must |

## 2. Non-Functional Requirements

| ID | Requirement | Target |
|---|---|---|
| NFR-001 | Core flow must work without paid services. | Mandatory |
| NFR-002 | API response should stay responsive under background work. | Mandatory |
| NFR-003 | Mobile list interactions should remain smooth on mid/low-tier devices. | Target |
| NFR-004 | Offline playback should work in airplane mode once file is saved. | Mandatory |
| NFR-005 | User-visible destructive actions require explicit confirmation. | Mandatory |
| NFR-006 | Flutter codebase should follow modular architecture and testability standards. | Mandatory |

## 3. API Contract Notes for Mobile

- Required fields per item:
  - `id`, `url`, `title`, `duration`, `status`
  - `file_size_bytes`, `filepath`, `audio_quality`
  - `playlist_name` (or `playlist_id`)
- Recommended extra fields:
  - `progress_percent`
  - `eta_seconds`

## 4. Definition of Done (Flutter MVP)

Flutter MVP is done when:

- URL add -> backend conversion -> ready playback flow works on Android device
- offline save/play works and offline visual indicator is clear
- delete confirmation is in place
- speed + autoplay preferences work consistently
- smoke integration tests pass
