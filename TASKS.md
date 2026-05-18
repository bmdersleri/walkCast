# walkCast — Implementation Backlog

## Phase A — Planning and Contract Freeze

- [ ] Finalize Flutter parity scope against PWA
- [ ] Freeze API payload contract for Flutter
- [ ] Decide local DB choice (`isar` primary, `hive` fallback)
- [ ] Define quality mapping and defaults (`good`, `medium`, `high`)

## Phase B — Flutter Project Bootstrap

- [ ] Create `apps/walkcast_mobile` with flavor-ready structure
- [ ] Add dependencies (`riverpod`, `dio`, `just_audio`, `audio_service`, `isar/hive`, `path_provider`)
- [ ] Setup linting, formatting, and CI test command
- [ ] Configure environment handling for API base URL

## Phase C — Data and Domain Layer

- [ ] Implement API client and typed DTO models
- [ ] Build repository layer with error mapping
- [ ] Add polling strategy for item status updates
- [ ] Implement local storage schema for offline files and preferences

## Phase D — Core UI and Playback

- [ ] Build queue list screen with card states (status/size/progress/ETA)
- [ ] Build add URL flow with playlist + quality controls
- [ ] Build player controls (play/pause, speed, autoplay-next)
- [ ] Handle listen-complete event and backend sync

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

- [ ] Create Flutter app skeleton and baseline folders
- [ ] Add API model for item including quality/size/progress fields
- [ ] Build queue screen static prototype from current design language
- [ ] Wire list fetch from backend and render live cards
- [ ] Implement quality radio selector on add URL form
- [ ] Implement offline save state toggle in UI
- [ ] Add first widget test for card state rendering

## Maintenance

- [x] Remove tracked runtime artifacts (`venv/`, `.run/`) from git history tip.
- [x] Enforce ignore rules for local/runtime directories in `.gitignore`.
