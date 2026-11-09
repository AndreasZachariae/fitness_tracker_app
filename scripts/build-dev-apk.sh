#!/usr/bin/env bash
# IM CONTAINER ausführen (release-dev.sh auf dem PC ruft es auf; darf auch Claude Code). Baut die DEV-App
# (de.gymlog.app.dev) im schnellen Release-Modus als dist/gymlog-dev.apk (64-Bit-ARM), signiert mit demselben
# Debug-Schlüssel wie install-dev.sh (~/.android im Container). Nutzt NICHT den Release-Schlüssel aus .secrets/.
#
#   ./scripts/build-dev-apk.sh [--quick]     --quick: ohne ./scripts/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo >&2
  echo "Abbruch: $*" >&2
  exit 1
}

{ read -r NAME; read -r CODE; } < <(./scripts/dev-version.sh)
echo "GymLog DEV $NAME (Build $CODE)"

if [ "${1:-}" != "--quick" ]; then
  echo
  echo "==> Format, Analyse, Tests"
  ./scripts/check.sh
fi

echo
echo "==> DEV-APK bauen (Build-Typ beta)"
flutter pub get >/dev/null
DEFINES="$(printf 'GYMLOG_DEV=true' | base64 -w0)"
(
  cd android
  ./gradlew -q :app:assembleBeta \
    -Ptarget-platform=android-arm64 \
    "-Pdart-defines=$DEFINES" \
    "-Pgymlog-version-code=$CODE" \
    "-Pgymlog-version-name=$NAME"
)
SRC="build/app/outputs/apk/beta/app-beta.apk"
[ -f "$SRC" ] || fail "$SRC wurde nicht erzeugt."

echo
echo "==> APK prüfen"
BUILD_TOOLS="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
BADGING="$("$BUILD_TOOLS/aapt2" dump badging "$SRC")"
[[ "$(head -1 <<<"$BADGING")" == *"name='de.gymlog.app.dev' versionCode='$CODE' versionName='$NAME'"* ]] ||
  fail "Paket/Version passen nicht: $(head -1 <<<"$BADGING")"
[ "$(grep '^native-code:' <<<"$BADGING")" = "native-code: 'arm64-v8a'" ] ||
  fail "Unerwartete Architekturen: $(grep '^native-code:' <<<"$BADGING")"
SIGNER="$("$BUILD_TOOLS/apksigner" verify --print-certs "$SRC" 2>/dev/null)" || fail "Signatur ungültig."
[[ "$SIGNER" == *"CN=Android Debug"* ]] || fail "Nicht mit dem Debug-Schlüssel signiert."

mkdir -p dist
cp "$SRC" dist/gymlog-dev.apk
echo "Fertig: dist/gymlog-dev.apk ($(du -h dist/gymlog-dev.apk | cut -f1)), de.gymlog.app.dev $NAME, Build $CODE"
