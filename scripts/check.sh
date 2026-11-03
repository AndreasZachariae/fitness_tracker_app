#!/usr/bin/env bash
# Formatierung, statische Analyse und Tests. Muss vor jedem Commit grün sein.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> dart format (ohne generierte Dateien)"
find lib test -name '*.dart' ! -name '*.g.dart' -print0 \
  | xargs -0 -r dart format --output=none --set-exit-if-changed

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test

echo "==> Alles grün."
