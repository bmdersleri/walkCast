# walkCast Mobile (Flutter)

This folder contains the native Flutter client for walkCast.

The mobile app is a queue/listener UI for audio items that are created from YouTube links via the browser extension and processed by the backend API.

## Where to use it

- Local web test (Chrome): run Flutter web and open the provided localhost URL.
- Android phone test: build/install APK and connect the app to your backend server.

## Prerequisites

- Flutter SDK (stable)
- Python 3 + backend dependencies (from repo root)
- Running backend API (`http://127.0.0.1:8000` by default)

## 1) Start backend API

From repository root:

```bash
cd /home/haytekllm/projects/walkcast
source .venv/bin/activate
python3 -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000 --reload
```

## 2) Run mobile app (web preview)

```bash
cd /home/haytekllm/projects/walkcast/apps/walkcast_mobile
flutter pub get
flutter run -d chrome \
  --web-hostname=127.0.0.1 \
  --web-port=40423 \
  --dart-define=WALKCAST_API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=WALKCAST_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

## 3) Build Android binaries (recommended)

```bash
cd /home/haytekllm/projects/walkcast/apps/walkcast_mobile
flutter build apk --release --split-per-abi --shrink \
  --dart-define=WALKCAST_API_BASE_URL=http://YOUR_SERVER_IP:8000 \
  --dart-define=WALKCAST_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

Split APK outputs:

`/home/haytekllm/projects/walkcast/apps/walkcast_mobile/build/app/outputs/flutter-apk/`

Common files:

- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

Build AAB (Play upload):

```bash
flutter build appbundle --release \
  --dart-define=WALKCAST_API_BASE_URL=http://YOUR_SERVER_IP:8000 \
  --dart-define=WALKCAST_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

Output AAB:

`/home/haytekllm/projects/walkcast/apps/walkcast_mobile/build/app/outputs/bundle/release/app-release.aab`

## 4) Distribute APK

Do not commit APK files into git history.
Upload APK/AAB artifacts to GitHub Releases:

- [https://github.com/bmdersleri/walkCast/releases](https://github.com/bmdersleri/walkCast/releases)
- Latest prepared mobile artifacts: [v0.1.0-mobile1](https://github.com/bmdersleri/walkCast/releases/tag/v0.1.0-mobile1)

## 5) Install APK (optional with ADB)

```bash
adb install -r /home/haytekllm/projects/walkcast/apps/walkcast_mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## How to use in app

1. Open `Settings` and set backend host/port if needed.
2. Return to queue screen and pull-to-refresh.
3. Filter items by playlist from the top chips.
4. Use top card controls for playback (`play/pause`, `prev/next`, `seek`, `rewind/forward`).
5. Downloaded state is shown by download icon color.
6. `Download playlist` downloads ready tracks sequentially with progress and ETA.

## About screen

Use the info icon in the app bar to open `About`:

- Repository URL: [https://github.com/bmdersleri/walkCast](https://github.com/bmdersleri/walkCast)
- Prepared by: Ismail Kirbas
- Version: app version + build number
- Build date: from `WALKCAST_BUILD_DATE`
