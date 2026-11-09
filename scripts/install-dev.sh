#!/usr/bin/env bash
# Baut die DEV-App (de.gymlog.app.dev), installiert sie aufs verbundene Handy und startet sie.
# Berührt die echte App (de.gymlog.app) nie.
set -euo pipefail
cd "$(dirname "$0")/.."

DEV_PKG="de.gymlog.app.dev"
APK="build/app/outputs/flutter-apk/app-debug.apk"

if ! adb get-state >/dev/null 2>&1; then
  echo "Kein Handy verbunden. Erst ./scripts/phone-connect-usb.sh (Kabel) oder ./scripts/phone-connect-wifi.sh (WLAN) ausführen." >&2
  exit 1
fi

# Gleiche Versionsnummer wie die DEV-Builds über GitHub (1.2.2), damit beide sich gegenseitig ersetzen.
{ read -r NAME; read -r CODE; } < <(./scripts/dev-version.sh)
flutter build apk --debug --build-name "$NAME" --build-number "$CODE"

AAPT2="$(find "$ANDROID_HOME/build-tools" -name aapt2 -type f | sort -V | tail -1)"
PKG="$("$AAPT2" dump packagename "$APK")"
if [ "$PKG" != "$DEV_PKG" ]; then
  echo "Abbruch: APK hat Paketnamen '$PKG', erwartet '$DEV_PKG'." >&2
  exit 1
fi

adb install -r "$APK"
adb shell monkey -p "$DEV_PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
echo "DEV-App installiert und gestartet."
