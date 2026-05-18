#!/usr/bin/env bash
set -euo pipefail

SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
CMDLINE_TOOLS_DIR="$SDK_ROOT/cmdline-tools"
LATEST_DIR="$CMDLINE_TOOLS_DIR/latest"

echo "[1/7] Installing Android Studio..."
sudo snap install android-studio --classic || true

echo "[2/7] Preparing SDK directories..."
mkdir -p "$CMDLINE_TOOLS_DIR"

if [[ ! -d "$LATEST_DIR/bin" ]]; then
  echo "[3/7] Android command-line tools not found."
  echo "Please open Android Studio once and install:"
  echo "- Android SDK Platform"
  echo "- Android SDK Build-Tools"
  echo "- Android SDK Platform-Tools"
  echo "- Android SDK Command-line Tools (latest)"
  echo "Then re-run this script."
  exit 1
fi

echo "[4/7] Exporting SDK environment variables..."
PROFILE_FILE="$HOME/.bashrc"
if ! grep -q "ANDROID_SDK_ROOT" "$PROFILE_FILE"; then
  {
    echo ""
    echo "# Android SDK for Flutter"
    echo "export ANDROID_SDK_ROOT=\"$SDK_ROOT\""
    echo "export PATH=\"\$PATH:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools\""
  } >> "$PROFILE_FILE"
fi

export ANDROID_SDK_ROOT="$SDK_ROOT"
export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools"

echo "[5/7] Configuring Flutter Android SDK path..."
flutter config --android-sdk "$ANDROID_SDK_ROOT"

echo "[6/7] Accepting Android licenses..."
yes | flutter doctor --android-licenses || true

echo "[7/7] Final doctor check..."
flutter doctor -v

echo "Android SDK setup completed."
