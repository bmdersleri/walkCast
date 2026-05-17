# PROJECT_BRIEF.md — walkCast

## 1. Project Identity

| Item | Value |
|---|---|
| Project name | walkCast |
| Repository | `https://github.com/bmdersleri/walkCast.git` |
| Tagline | Save videos now, listen later automatically. |
| Short description | A self-hosted playlist management and automated YouTube-to-MP3 extraction system for turning learning videos into a mobile listening workflow. |
| Primary owner | Project owner / repository maintainer |
| Target users | Academics, students, researchers, lifelong learners |
| Deployment | Personal or institutional self-hosted Ubuntu server |

---

## 2. Problem Statement

Many valuable educational and technical materials are published as videos. Users often discover them while working at a desktop computer but want to consume the content later on a phone, especially while walking or commuting. Existing tools require manual downloading, transferring files to the phone, or keeping the screen on for video apps.

walkCast solves this by automating the pipeline:
1. **Collect video URLs** directly via a Chrome Extension.
2. **Automatically extract and convert** the audio (MP3) on a personal self-hosted server using `yt-dlp` and `FFmpeg`.
3. **Consume and manage** the audio via a mobile PWA with auto-cleanup features.

---

## 3. Vision

walkCast should become a completely private, automated learning audio pipeline:

`Discover video → Extension Click → Server Downloads & Converts to MP3 → Listen on Phone → Auto-Delete`

---

## 4. Target Use Cases

### UC-01 — Save a useful video page
A user opens a lecture or tutorial in Chrome and saves it to a walkCast playlist with one click. 

### UC-02 — Automated Background Processing
Once saved, the backend immediately extracts metadata (title, duration) and starts downloading and converting the video to MP3 in the background. The user sees real-time progress.

### UC-03 — Listen and Manage on Phone
The user opens the mobile PWA, sees the generated MP3 files with their durations, and listens directly from the server.

### UC-04 — Listen & Delete Workflow
After finishing a track, the system marks it as "Listened" and prompts the user to delete it, freeing up server storage space.

---

## 5. Product Principles

1. **Self-hosted & Private:** No public SaaS. All data and MP3 files stay on the user's server.
2. **Automated:** No manual file uploads. The server handles extraction via `yt-dlp`.
3. **Storage-Conscious:** Easy deletion of physical files from the server after listening.
4. **Mobile-friendly:** Listening on a phone is a first-class workflow.
5. **No AI/Agent Dependency:** The system is triggered purely by explicit user actions.