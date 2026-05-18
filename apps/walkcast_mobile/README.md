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

## 3) Build APK for Android

```bash
cd /home/haytekllm/projects/walkcast/apps/walkcast_mobile
flutter build apk --release \
  --dart-define=WALKCAST_API_BASE_URL=http://YOUR_SERVER_IP:8000 \
  --dart-define=WALKCAST_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

Output APK:

`/home/haytekllm/projects/walkcast/apps/walkcast_mobile/build/app/outputs/flutter-apk/app-release.apk`

## 4) Install APK (optional with ADB)

```bash
adb install -r /home/haytekllm/projects/walkcast/apps/walkcast_mobile/build/app/outputs/flutter-apk/app-release.apk
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
