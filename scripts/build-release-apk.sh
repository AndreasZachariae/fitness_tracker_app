#!/usr/bin/env bash
# IM CONTAINER ausführen. Baut die ECHTE App (de.gymlog.app) als APK-Datei zum Weitergeben oder Installieren
# ohne Kabel/WLAN-Verbindung. Ergebnis: dist/gymlog-<version>.apk. Installiert nichts.
# Nur 64-Bit-ARM (~23 MB statt ~70 MB): läuft auf praktisch jedem Handy seit 2017. Die Versionsnummer (versionCode)
# bleibt dieselbe wie beim vollen Build, Updates in beide Richtungen funktionieren.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .secrets/key.properties ]; then
  echo "Kein Signaturschlüssel gefunden. Erst ./scripts/create-keystore.sh ausführen (README, Einrichtung)." >&2
  exit 1
fi

flutter build apk --release --target-platform android-arm64

VERSION="$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' pubspec.yaml)"
mkdir -p dist
OUT="dist/gymlog-${VERSION}.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT"

echo
echo "Fertig: $OUT ($(du -h "$OUT" | cut -f1))"
echo "SHA-256: $(sha256sum "$OUT" | cut -d' ' -f1)"
echo "Aufs Handy bringen (Kabel, Cloud, Mail), in der Dateien-App antippen, Installation aus dieser Quelle erlauben."
