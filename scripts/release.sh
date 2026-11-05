#!/usr/bin/env bash
# IM CONTAINER ausführen – nur durch dich, nie durch Claude Code. Veröffentlicht die Version aus pubspec.yaml als
# GitHub-Release:
#   1. prüft: GitHub-Login, Schlüssel, Branch main, alles committet, Version/Tag neu, Roadmap-Status FINISHED,
#      Changelog-Abschnitt vorhanden, ./scripts/check.sh grün
#   2. baut und signiert dist/gymlog-<version>.apk (64-Bit-ARM) und prüft Paket, Version und Signaturschlüssel
#   3. zeigt den Release-Text und fragt nach – bis hierhin wird nichts veröffentlicht oder committet
#   4. trägt Datum und Commits in CHANGELOG.md ein, committet "chore(release): vX.Y.Z", setzt den Tag vX.Y.Z,
#      pusht main + Tag und erstellt die GitHub-Release mit der APK
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="AndreasZachariae/fitness_tracker_app"
PACKAGE="de.gymlog.app"
CERT_FILE=".github/signing-certificate.sha256"
BUILD_TOOLS="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
# git über den Login der GitHub CLI (keine Passwörter in git gespeichert).
GIT_AUTH=(-c "credential.helper=" -c "credential.helper=!gh auth git-credential")

fail() {
  echo >&2
  echo "Abbruch: $*" >&2
  exit 1
}
step() {
  echo
  echo "==> $*"
}

step "Voraussetzungen"
command -v gh >/dev/null ||
  fail "GitHub CLI 'gh' fehlt. Auf dem PC: docker compose up -d --build (README, Abschnitt Release)."
gh auth status --hostname github.com >/dev/null 2>&1 ||
  fail "Nicht bei GitHub angemeldet. Einmalig im Container: gh auth login (README, Abschnitt Release)."
[ -f .secrets/key.properties ] || fail "Kein Signaturschlüssel (.secrets/key.properties)."
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || fail "Releases nur vom Branch main."
[ -z "$(git status --porcelain)" ] || fail "Es gibt nicht committete Änderungen (git status)."
git "${GIT_AUTH[@]}" fetch --quiet --tags origin main
git merge-base --is-ancestor origin/main HEAD ||
  fail "Auf GitHub (origin/main) gibt es Commits, die hier fehlen. Erst: git pull"

step "Version"
FULL="$(sed -n 's/^version: *\([^ ]*\).*/\1/p' pubspec.yaml)"
[[ "$FULL" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]] ||
  fail "version in pubspec.yaml hat nicht die Form X.Y.Z+N: '$FULL'"
VERSION="${BASH_REMATCH[1]}"
BUILD="${BASH_REMATCH[2]}"
TAG="v$VERSION"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then fail "Tag $TAG gibt es schon (lokal)."; fi
if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  fail "Tag $TAG gibt es auf GitHub schon. Für ein neues Release erst die Version in pubspec.yaml erhöhen."
fi
PREV_TAG="$(git describe --tags --abbrev=0 --match 'v[0-9]*' HEAD 2>/dev/null || true)"
if [ -n "$PREV_TAG" ]; then
  PREV_BUILD="$(git show "$PREV_TAG:pubspec.yaml" | sed -n 's/^version: *[^+]*+\([0-9]*\).*/\1/p')"
  [ "$BUILD" -gt "$PREV_BUILD" ] ||
    fail "Build-Nummer $BUILD muss größer sein als $PREV_BUILD von $PREV_TAG (sonst lehnt Android das Update ab)."
  [ "$(printf '%s\n%s\n' "${PREV_TAG#v}" "$VERSION" | sort -V | tail -1)" = "$VERSION" ] ||
    fail "Version $VERSION ist nicht neuer als $PREV_TAG."
fi
echo "GymLog $VERSION (Build $BUILD), Tag $TAG, vorheriges Release: ${PREV_TAG:-keins}"

step "Roadmap und Changelog"
STATUS="$(awk -v v="$VERSION" '
  found && /STATUS:/ { sub(/.*STATUS:[ \t]*/, ""); sub(/[ \t\r]+$/, ""); print; exit }
  index($0, "Version " v) == 1 { found = 1 }
' docs/ROADMAP.md)"
[ "$STATUS" = FINISHED ] ||
  fail "Version $VERSION steht in docs/ROADMAP.md auf '${STATUS:-nicht gefunden}'. Veröffentlicht wird nur mit STATUS: FINISHED (nach bestandener Handy-Testliste setzen und committen)."
./scripts/release-notes.sh check "$VERSION"
echo "Roadmap: FINISHED, CHANGELOG.md: Abschnitt [$VERSION] vorhanden."

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
  echo "Signaturschlüssel wie bei den bisherigen Releases."
else
  echo "Erstes Release: Der Fingerabdruck des Schlüssels wird in $CERT_FILE gespeichert und ab jetzt geprüft."
fi
SHA="$(sha256sum "$APK" | cut -d' ' -f1)"

NOTES="dist/release-notes-$VERSION.md"
{
  ./scripts/release-notes.sh notes "$VERSION"
  printf '\nSHA-256 von `gymlog-%s.apk`: `%s`\n' "$VERSION" "$SHA"
} >"$NOTES"

step "Vorschau"
echo "----------------------------------------------------------------------"
cat "$NOTES"
echo "----------------------------------------------------------------------"
UNPUSHED="$(git rev-list --count origin/main..HEAD)"
echo "Release:     GymLog $VERSION (Build $BUILD), Tag $TAG"
echo "APK:         $APK ($(du -h "$APK" | cut -f1)), SHA-256 $SHA"
echo "Schlüssel:   $DN"
echo "             SHA-256 $CERT"
echo "Push:        $UNPUSHED Commit(s) + Release-Commit nach origin/main (öffentlich: https://github.com/$REPO)"
echo
read -r -p "GymLog $VERSION jetzt veröffentlichen? Zum Bestätigen 'ja' eingeben: " ANSWER
if [ "$ANSWER" != ja ]; then
  echo "Nichts veröffentlicht, nichts committet. APK und Release-Text liegen in dist/."
  exit 0
fi

step "Changelog, Commit und Tag"
DATE="$(date +%F)"
./scripts/release-notes.sh finalize "$VERSION" "$DATE" >CHANGELOG.md.new
mv CHANGELOG.md.new CHANGELOG.md
git add CHANGELOG.md
if [ ! -f "$CERT_FILE" ]; then
  echo "$CERT" >"$CERT_FILE"
  git add "$CERT_FILE"
fi
ID=()
git config user.name >/dev/null || ID+=(-c "user.name=$(git log -1 --format=%an)")
git config user.email >/dev/null || ID+=(-c "user.email=$(git log -1 --format=%ae)")
git "${ID[@]}" commit --quiet -m "chore(release): $TAG"
git "${ID[@]}" tag -a "$TAG" -m "GymLog $VERSION"

step "Push nach GitHub"
if ! git "${GIT_AUTH[@]}" push --atomic origin main "$TAG"; then
  echo >&2
  echo "Push fehlgeschlagen, auf GitHub hat sich nichts geändert. Lokal zurücksetzen und später neu starten:" >&2
  echo "  git tag -d $TAG && git reset --hard HEAD~1" >&2
  exit 1
fi

step "GitHub-Release erstellen"
RELEASE_CMD=(gh release create "$TAG" "$APK" --repo "$REPO" --title "GymLog $VERSION"
  --notes-file "$NOTES" --verify-tag --latest)
if ! "${RELEASE_CMD[@]}"; then
  echo >&2
  echo "Commit und Tag sind auf GitHub, aber die Release fehlt. Erneut versuchen mit:" >&2
  printf '  %q' "${RELEASE_CMD[@]}" >&2
  echo >&2
  exit 1
fi

echo
echo "Fertig: $(gh release view "$TAG" --repo "$REPO" --json url --jq .url)"
echo "Zum Weitergeben immer gültig: https://github.com/$REPO/releases/latest"
