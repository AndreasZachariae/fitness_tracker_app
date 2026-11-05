#!/usr/bin/env bash
# Läuft IM CONTAINER und wird nur von scripts/release.sh (auf dem PC) aufgerufen – nicht von Hand, nie von Claude Code.
# Testet, baut und signiert die Release-APK und prüft sie. Kein Zugriff auf GitHub, veröffentlicht nichts.
#
#   ./scripts/release-build.sh <version> <build-nummer>
#
# Ergebnis: dist/gymlog-<version>.apk und dist/gymlog-<version>.signing (Zeilen "cert=…" und "dn=…").
set -euo pipefail
cd "$(dirname "$0")/.."

[ $# -eq 2 ] || { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
VERSION="$1"
BUILD="$2"
PACKAGE="de.gymlog.app"
CERT_FILE=".github/signing-certificate.sha256"
BUILD_TOOLS="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"

fail() {
  echo >&2
  echo "Abbruch: $*" >&2
  exit 1
}
step() {
  echo
  echo "==> $*"
}

step "Format, Analyse, Tests"
./scripts/check.sh

step "Release-APK bauen"
./scripts/build-release-apk.sh
APK="dist/gymlog-$VERSION.apk"
[ -f "$APK" ] || fail "$APK wurde nicht erzeugt."

step "APK prüfen"
BADGING="$("$BUILD_TOOLS/aapt2" dump badging "$APK")"
[[ "$(head -1 <<<"$BADGING")" == *"name='$PACKAGE' versionCode='$BUILD' versionName='$VERSION'"* ]] ||
  fail "Paket/Version der APK passen nicht: $(head -1 <<<"$BADGING")"
[ "$(grep '^native-code:' <<<"$BADGING")" = "native-code: 'arm64-v8a'" ] ||
  fail "Unerwartete Prozessor-Architekturen: $(grep '^native-code:' <<<"$BADGING")"
SIGNER="$("$BUILD_TOOLS/apksigner" verify --print-certs "$APK" 2>/dev/null)" || fail "Signatur der APK ist ungültig."
CERT="$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' <<<"$SIGNER")"
DN="$(sed -n 's/^Signer #1 certificate DN: //p' <<<"$SIGNER")"
[ -n "$CERT" ] || fail "Kein Signaturzertifikat gefunden."
[[ "$DN" != *"Android Debug"* ]] || fail "APK ist mit dem Debug-Schlüssel signiert, nicht mit deinem Release-Schlüssel."
if [ -f "$CERT_FILE" ]; then
  [ "$CERT" = "$(tr -d '[:space:]' <"$CERT_FILE")" ] ||
    fail "APK ist mit einem ANDEREN Schlüssel signiert als die bisherigen Releases ($CERT_FILE). Updates würden fehlschlagen. .secrets/ aus der Sicherung zurückholen."
  echo "Paket, Version, Architektur ok; Signaturschlüssel wie bei den bisherigen Releases."
else
  echo "Paket, Version, Architektur ok; erstes Release, der Schlüssel-Fingerabdruck wird gespeichert."
fi
printf 'cert=%s\ndn=%s\n' "$CERT" "$DN" >"dist/gymlog-$VERSION.signing"
