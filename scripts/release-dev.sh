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
# Einmalig: GitHub-Token (fine-grained, nur dieses Repository, Berechtigung "Contents: Read and write") in
#   ~/.config/gymlog/github-token   (chmod 600) – liegt außerhalb des Projektordners, der Container sieht ihn nie.
# Voraussetzungen auf dem PC: git mit SSH-Schlüssel bei GitHub, curl, python3, Docker.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="AndreasZachariae/fitness_tracker_app"
API="https://api.github.com/repos/$REPO"
PUSH_URL="git@github.com:$REPO.git"
TOKEN_FILE="${GYMLOG_GITHUB_TOKEN_FILE:-$HOME/.config/gymlog/github-token}"
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
for tool in git curl python3 docker; do
  command -v "$tool" >/dev/null || fail "$tool fehlt auf dem PC."
done
[ -f "$TOKEN_FILE" ] || fail "Kein GitHub-Token in $TOKEN_FILE (README, Abschnitt DEV-App über GitHub)."
TOKEN="$(tr -d '[:space:]' <"$TOKEN_FILE")"
[ -n "$TOKEN" ] || fail "$TOKEN_FILE ist leer."
docker compose ps --status running --services 2>/dev/null | grep -qx dev ||
  fail "Der Container läuft nicht. Erst: docker compose up -d"
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || fail "DEV-Builds nur vom Branch main."
[ -z "$(git status --porcelain)" ] || fail "Es gibt nicht committete Änderungen (git status)."
git ls-remote "$PUSH_URL" HEAD >/dev/null || fail "Kein SSH-Zugang zu GitHub ($PUSH_URL). Prüfen mit: ssh -T git@github.com"
# Nur main und Versions-Tags holen; der Tag "dev" wandert und würde sonst bei jedem Fetch stören.
git fetch --quiet origin main 'refs/tags/v*:refs/tags/v*'
git merge-base --is-ancestor origin/main HEAD ||
  fail "Auf GitHub (origin/main) gibt es Commits, die hier fehlen. Erst: git pull"

RESP="$(mktemp)"
trap 'rm -f "$RESP"' EXIT

# api METHOD PATH [JSON-BODY]: Antwort in $RESP, HTTP-Status in $STATUS (keine Subshell, damit beides ankommt).
api() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -o "$RESP" -w '%{http_code}' -X "$method"
    -H "Authorization: Bearer $TOKEN"
    -H 'Accept: application/vnd.github+json'
    -H 'X-GitHub-Api-Version: 2022-11-28')
  if [ -n "$body" ]; then
    args+=(-H 'Content-Type: application/json' --data-binary "$body")
  fi
  STATUS="$(curl "${args[@]}" "$API$path")"
}
# Wert aus der letzten Antwort, z. B. json "['id']".
json() { python3 -c "import json,sys; print(json.load(open(sys.argv[1]))$1)" "$RESP"; }

api GET ""
[ "$STATUS" = 200 ] || fail "Der Token wird von GitHub nicht akzeptiert (HTTP $STATUS)."

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

step "Vorab-Release \"$TAG\" ersetzen"
api GET "/releases/tags/$TAG"
if [ "$STATUS" = 200 ]; then
  id="$(json "['id']")"
  api DELETE "/releases/$id"
  [ "$STATUS" = 204 ] || fail "Alte DEV-Release ließ sich nicht löschen (HTTP $STATUS)."
fi
# Den alten Tag auch entfernen (404, wenn es ihn nicht gibt, ist in Ordnung).
api DELETE "/git/refs/tags/$TAG"

BODY="$(python3 - "$NAME" "$SHA" "$NOTES" "$TAG" <<'PY'
import json, sys
name, sha, notes, tag = sys.argv[1:]
print(json.dumps({
    "tag_name": tag,
    "target_commitish": sha,
    "name": f"GymLog DEV {name}",
    "body": open(notes, encoding="utf-8").read(),
    "prerelease": True,
    "make_latest": "false",
}))
PY
)"
api POST "/releases" "$BODY"
[ "$STATUS" = 201 ] || fail "DEV-Release ließ sich nicht anlegen (HTTP $STATUS): $(cat "$RESP")"
id="$(json "['id']")"
url="$(json "['html_url']")"
# Ein lokaler Tag "dev" (von einem früheren git pull) zeigt jetzt auf den alten Stand; weg damit, sonst meldet der
# nächste git pull "would clobber existing tag".
git tag -d "$TAG" >/dev/null 2>&1 || true

step "APK hochladen"
status="$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/vnd.android.package-archive' \
  --data-binary "@$APK" \
  "https://uploads.github.com/repos/$REPO/releases/$id/assets?name=gymlog-dev.apk")"
[ "$status" = 201 ] || fail "Upload der APK fehlgeschlagen (HTTP $status). Einfach erneut starten."

echo
echo "Fertig: GymLog DEV $NAME (Build $CODE)"
echo "  $url"
echo "GymLog DEV am Handy zeigt das Update beim nächsten Öffnen."
