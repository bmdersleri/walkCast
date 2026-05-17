# PRODUCT_REQUIREMENTS.md — walkCast

## 1. Functional Requirements

### 1.1 Chrome Extension
| ID | Requirement | Priority |
|---|---|---|
| FR-EXT-001 | The extension shall capture the active tab URL and send it to the backend. | Must |
| FR-EXT-002 | The extension shall display the playlist items with Title and Duration. | Must |
| FR-EXT-003 | The extension shall allow the user to delete an item and its associated physical file directly from the UI. | Must |
| FR-EXT-004 | The extension shall display real-time status (downloading, ready, listened). | Must |

### 1.2 Backend API & Database
| ID | Requirement | Priority |
|---|---|---|
| FR-API-001 | The backend shall accept URLs and trigger a background extraction task. | Must |
| FR-API-002 | The backend database shall store `title`, `duration` (string/seconds), and `is_listened` (boolean) for each item. | Must |
| FR-API-003 | The backend shall track and update states: `queued`, `downloading`, `converting_mp3`, `ready`, `error`. | Must |
| FR-API-004 | The `DELETE /items/{id}` endpoint shall remove both the database record and the physical MP3 file from storage. | Must |
| FR-API-005 | The backend shall serve generated audio files to the authenticated PWA via stream/download. | Must |

### 1.3 Audio Processing Engine (yt-dlp Worker)
| ID | Requirement | Priority |
|---|---|---|
| FR-AUD-001 | The system shall use `yt-dlp` and `aria2c` for high-speed audio extraction. | Must |
| FR-AUD-002 | The system shall use FFmpeg to convert the downloaded stream to MP3. | Must |
| FR-AUD-003 | The worker shall use `progress_hooks` to update the database with download percentage and processing status. | Must |
| FR-AUD-004 | The worker shall extract and save video Title and Duration before downloading begins. | Must |

### 1.4 Mobile PWA
| ID | Requirement | Priority |
|---|---|---|
| FR-PWA-001 | The mobile UI shall list items with their Title, Duration, and Processing Status. | Must |
| FR-PWA-002 | The mobile UI shall play generated audio files using the native HTML5 `<audio>` player. | Must |
| FR-PWA-003 | The mobile UI shall detect the `onended` event of the audio player to mark the item as `is_listened`. | Must |
| FR-PWA-004 | The mobile UI shall prompt the user to delete the file from the server upon finishing the audio. | Should |

---

## 2. Non-Functional Requirements
| ID | Requirement | Target |
|---|---|---|
| NFR-001 | The system shall run without paid services or third-party APIs (relying entirely on yt-dlp). | Mandatory |
| NFR-002 | Background tasks shall not block the FastAPI request/response lifecycle. | Mandatory |