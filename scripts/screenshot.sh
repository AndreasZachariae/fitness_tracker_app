#!/usr/bin/env bash
# Screenshot vom verbundenen Handy nach build/screenshots/. Gibt den Dateipfad aus.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/screenshots
OUT="build/screenshots/${1:-screen}-$(date +%Y%m%d-%H%M%S).png"
adb exec-out screencap -p > "$OUT"
echo "$OUT"
