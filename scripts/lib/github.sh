# shellcheck shell=bash
# Gemeinsamer GitHub-Teil von release.sh und release-dev.sh – NUR AUF DEM PC (eingebunden mit "source").
# Releases anlegen und APKs hochladen geht nicht über git/SSH, sondern nur über GitHubs Schnittstelle; dafür ein
# fine-grained Token (nur dieses Repository, "Contents: Read and write") in ~/.config/gymlog/github-token. Er liegt
# außerhalb des Projektordners, der Container sieht ihn nie. Erwartet: REPO und fail().

GITHUB_TOKEN_FILE="${GYMLOG_GITHUB_TOKEN_FILE:-$HOME/.config/gymlog/github-token}"
API="${GYMLOG_GITHUB_API:-https://api.github.com}/repos/$REPO"
UPLOADS="${GYMLOG_GITHUB_UPLOADS:-https://uploads.github.com}/repos/$REPO"

# Token lesen und bei GitHub prüfen.
github_init() {
  local tool
  for tool in curl python3; do
    command -v "$tool" >/dev/null || fail "$tool fehlt auf dem PC."
  done
  [ -f "$GITHUB_TOKEN_FILE" ] ||
    fail "Kein GitHub-Token in $GITHUB_TOKEN_FILE (README, Abschnitt \"Einmalig: GitHub-Token\")."
  TOKEN="$(tr -d '[:space:]' <"$GITHUB_TOKEN_FILE")"
  [ -n "$TOKEN" ] || fail "$GITHUB_TOKEN_FILE ist leer."
  RESP="$(mktemp)"
  trap 'rm -f "$RESP"' EXIT
  api GET ""
  [ "$STATUS" = 200 ] ||
    fail "Der GitHub-Token wird nicht akzeptiert (HTTP $STATUS). Abgelaufen? Neu anlegen wie im README beschrieben."
}

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
  STATUS="$(curl "${args[@]}" "$API$path" || echo 000)"
}

# Wert aus der letzten Antwort, z. B. json "['id']".
json() { python3 -c "import json,sys; print(json.load(open(sys.argv[1]))$1)" "$RESP"; }

# release_body TAG TARGET NAME NOTES-DATEI PRERELEASE(true/false): JSON für einen Release-Entwurf.
release_body() {
  python3 - "$@" <<'PY'
import json, sys
tag, target, name, notes, prerelease = sys.argv[1:]
print(json.dumps({
    "tag_name": tag,
    "target_commitish": target,
    "name": name,
    "body": open(notes, encoding="utf-8").read(),
    "draft": True,
    "prerelease": prerelease == "true",
}))
PY
}

# publish_release TAG TARGET NAME NOTES APK ASSET-NAME PRERELEASE LATEST(true/false)
# Legt die Release als Entwurf an, lädt die APK hoch und veröffentlicht erst dann – so sieht niemand (auch nicht die
# Update-Suche der App) eine Release ohne APK. Bei einem Fehler wird der Entwurf wieder gelöscht.
# Ergebnis: RELEASE_URL; Rückgabewert 1 bei Fehler (Meldung auf stderr).
publish_release() {
  local tag="$1" target="$2" name="$3" notes="$4" apk="$5" asset="$6" prerelease="$7" latest="$8" id status
  api POST "/releases" "$(release_body "$tag" "$target" "$name" "$notes" "$prerelease")"
  if [ "$STATUS" != 201 ]; then
    echo "Release-Entwurf ließ sich nicht anlegen (HTTP $STATUS): $(cat "$RESP")" >&2
    return 1
  fi
  id="$(json "['id']")"
  echo "APK hochladen ($(du -h "$apk" | cut -f1)) …"
  status="$(curl -sS -o "$RESP" -w '%{http_code}' -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Accept: application/vnd.github+json' \
    -H 'Content-Type: application/vnd.android.package-archive' \
    --data-binary "@$apk" \
    "$UPLOADS/releases/$id/assets?name=$asset" || echo 000)"
  if [ "$status" != 201 ]; then
    echo "Upload der APK fehlgeschlagen (HTTP $status)." >&2
    api DELETE "/releases/$id"
    return 1
  fi
  api PATCH "/releases/$id" "{\"draft\": false, \"make_latest\": \"$latest\"}"
  if [ "$STATUS" != 200 ]; then
    echo "Veröffentlichen fehlgeschlagen (HTTP $STATUS): $(cat "$RESP")" >&2
    api DELETE "/releases/$id"
    return 1
  fi
  RELEASE_URL="$(json "['html_url']")"
}
