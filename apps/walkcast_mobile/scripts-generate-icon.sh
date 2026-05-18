#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

SVG="assets/icon/walkcast_runner.svg"
PNG="assets/icon/walkcast_runner.png"

if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert "$SVG" -w 1024 -h 1024 -o "$PNG"
elif command -v inkscape >/dev/null 2>&1; then
  inkscape "$SVG" --export-type=png --export-filename="$PNG" --export-width=1024 --export-height=1024
else
  echo "Install one of these first:"
  echo "  sudo apt install -y librsvg2-bin"
  echo "or"
  echo "  sudo apt install -y inkscape"
  exit 1
fi

flutter pub run flutter_launcher_icons -f flutter_launcher_icons.yaml

echo "Icon generated and applied."
