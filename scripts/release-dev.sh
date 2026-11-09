#!/usr/bin/env bash
# AUF DEM PC ausführen (nicht im Container), im Projektordner, Container läuft. Nur durch dich, nie durch Claude Code.
# Veröffentlicht den aktuellen Stand als DEV-Build über GitHub (1.2.2): genau EINE Vorab-Release mit dem Tag "dev",
# die bei jedem Lauf ersetzt wird. GymLog DEV am Handy findet sie beim nächsten Öffnen und bietet das Update an.
#   1. prüft: GitHub-Token, SSH-Zugang, Branch main, alles committet, Stand von GitHub
#   2. im Container: Tests und DEV-APK (scripts/build-dev-apk.sh, Debug-Schlüssel des Containers)
#   3. pusht main per SSH, ersetzt die Vorab-Release "dev" (Text: Testliste fürs Handy, Änderungen, Commits)
#      und lädt dist/gymlog-dev.apk hoch
#
#   ./scripts/release-dev.sh [--quick]     --quick: ohne Tests (nur für Text-/Layout-Kleinigkeiten)
#
# Einmalig: GitHub-Token in ~/.config/gymlog/github-token (README, "Einmalig: GitHub-Token"; derselbe wie für
#   release.sh) – liegt außerhalb des Projektordners, der Container sieht ihn nie.
# Voraussetzungen auf dem PC: git mit SSH-Schlüssel bei GitHub, curl, python3, Docker.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="AndreasZachariae/fitness_tracker_app"
PUSH_URL="git@github.com:$REPO.git"
TAG="dev"

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
[ ! -f /.dockerenv ] || fail "Dieses Skript läuft auf dem PC, nicht im Container (dort gibt es absichtlich keinen GitHub-Zugang)."
for tool in git docker; do
  command -v "$tool" >/dev/null || fail "$tool fehlt auf dem PC."
done
# shellcheck source=lib/github.sh
source scripts/lib/github.sh
github_init
docker compose ps --status running --services 2>/dev/null | grep -qx dev ||
  fail "Der Container läuft nicht. Erst: docker compose up -d"
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || fail "DEV-Builds nur vom Branch main."
[ -z "$(git status --porcelain)" ] || fail "Es gibt nicht committete Änderungen (git status)."
git ls-remote "$PUSH_URL" HEAD >/dev/null || fail "Kein SSH-Zugang zu GitHub ($PUSH_URL). Prüfen mit: ssh -T git@github.com"
# Nur main und Versions-Tags holen; der Tag "dev" wandert und würde sonst bei jedem Fetch stören.
git fetch --quiet origin main 'refs/tags/v*:refs/tags/v*'
git merge-base --is-ancestor origin/main HEAD ||
  fail "Auf GitHub (origin/main) gibt es Commits, die hier fehlen. Erst: git pull"

step "Im Container: testen und DEV-APK bauen"
docker compose exec -T dev ./scripts/build-dev-apk.sh "$@"
{ read -r NAME; read -r CODE; } < <(./scripts/dev-version.sh)
APK="dist/gymlog-dev.apk"
[ -f "$APK" ] || fail "Der Container hat keine APK geliefert."
[ -z "$(git status --porcelain)" ] || fail "Der Build hat Dateien im Repository verändert (git status)."

NOTES="dist/release-notes-dev.md"
./scripts/release-notes.sh dev "$NAME" >"$NOTES"

step "Push nach GitHub"
git push "$PUSH_URL" HEAD:main
SHA="$(git rev-parse HEAD)"

step "Vorab-Release \"$TAG\" ersetzen (Entwurf, APK hochladen, veröffentlichen)"
api GET "/releases/tags/$TAG"
if [ "$STATUS" = 200 ]; then
  id="$(json "['id']")"
  api DELETE "/releases/$id"
  [ "$STATUS" = 204 ] || fail "Alte DEV-Release ließ sich nicht löschen (HTTP $STATUS)."
fi
# Den alten Tag auch entfernen (404, wenn es ihn nicht gibt, ist in Ordnung).
api DELETE "/git/refs/tags/$TAG"

publish_release "$TAG" "$SHA" "GymLog DEV $NAME" "$NOTES" "$APK" gymlog-dev.apk true false ||
  fail "Die DEV-Release ist nicht veröffentlicht. Einfach erneut starten."
# Ein lokaler Tag "dev" (von einem früheren git pull) zeigt jetzt auf den alten Stand; weg damit, sonst meldet der
# nächste git pull "would clobber existing tag".
git tag -d "$TAG" >/dev/null 2>&1 || true

echo
echo "Fertig: GymLog DEV $NAME (Build $CODE)"
echo "  $RELEASE_URL"
echo "GymLog DEV am Handy zeigt das Update beim nächsten Öffnen."
