#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/haytekllm/projects/walkcast-clean"
INSTALL_FLUTTER="${1:-yes}" # yes|no

echo "[1/5] Installing base Ubuntu packages..."
sudo apt update
sudo apt install -y \
  python3 python3-venv python3-pip \
  ffmpeg \
  curl wget git ca-certificates \
  build-essential pkg-config \
  sqlite3

echo "[2/5] Installing optional downloader (aria2)..."
sudo apt install -y aria2 || true

echo "[3/5] Creating/updating Python virtual environment..."
cd "${PROJECT_DIR}"
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip setuptools wheel
pip install -r requirements.txt

echo "[4/5] Verifying backend toolchain..."
python --version
ffmpeg -version | head -n 2
aria2c --version | head -n 2 || true
pytest -q backend/tests/test_items_api.py || true

if [[ "${INSTALL_FLUTTER}" == "yes" ]]; then
  echo "[5/5] Installing Flutter prerequisites and Flutter SDK..."
  sudo apt update
  sudo apt install -y clang cmake ninja-build libgtk-3-dev liblzma-dev unzip

  if ! command -v flutter >/dev/null 2>&1; then
    sudo snap install flutter --classic
  else
    echo "Flutter already installed, skipping snap install."
  fi

  flutter --version
  flutter doctor || true
else
  echo "[5/5] Skipping Flutter install (pass 'yes' to enable)."
fi

echo "Setup completed."
