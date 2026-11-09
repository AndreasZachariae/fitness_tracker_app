#!/usr/bin/env bash
# AUF DEM PC ausführen (nicht im Container), im Projektordner, Container läuft. Nur durch dich.
# Veröffentlicht die Version aus pubspec.yaml als GitHub-Release. Gepusht wird mit deinem SSH-Schlüssel auf dem PC;
# der Container testet, baut und signiert nur (scripts/release-build.sh) und kommt nie an GitHub heran.
#   1. prüft: SSH-Zugang zu GitHub, Branch main, alles committet, Stand von GitHub, Version/Tag neu,
#      Roadmap-Status FINISHED, Changelog-Abschnitt vorhanden
#   2. im Container: Tests, APK bauen und signieren, Paket/Version/Signaturschlüssel prüfen
#   3. zeigt den Release-Text und fragt nach – bis hierhin wird nichts veröffentlicht oder committet
#   4. trägt Datum und Commits in CHANGELOG.md ein, committet "chore(release): vX.Y.Z", setzt den Tag vX.Y.Z und
#      pusht main + Tag per SSH
#   5. öffnet die vorausgefüllte Release-Seite im Browser: APK hineinziehen, "Publish release" (ein SSH-Schlüssel
#      reicht für git, aber nicht für GitHubs Release-Schnittstelle; so braucht es weder gh noch einen Token)
# Voraussetzungen auf dem PC: git, SSH-Schlüssel bei GitHub hinterlegt (ssh -T git@github.com), Docker.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="AndreasZachariae/fitness_tracker_app"
# Push über SSH, unabhängig davon, ob origin per HTTPS eingetragen ist (gelesen wird weiter über origin).
PUSH_URL="git@github.com:$REPO.git"
CERT_FILE=".github/signing-certificate.sha256"

fail() {
  echo >&2
  echo "Abbruch: $*" >&2
  exit 1
}
step() {
  echo
  echo "==> $*"
}
sha256() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

step "Voraussetzungen"
[ ! -f /.dockerenv ] || fail "Dieses Skript läuft auf dem PC, nicht im Container (dort gibt es absichtlich keinen GitHub-Zugang)."
command -v git >/dev/null || fail "git fehlt."
command -v docker >/dev/null || fail "docker fehlt."
git ls-remote "$PUSH_URL" HEAD >/dev/null ||
  fail "Kein SSH-Zugang zu GitHub ($PUSH_URL). Prüfen mit: ssh -T git@github.com"
docker compose ps --status running --services 2>/dev/null | grep -qx dev ||
  fail "Der Container läuft nicht. Erst: docker compose up -d"
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || fail "Releases nur vom Branch main."
[ -z "$(git status --porcelain)" ] || fail "Es gibt nicht committete Änderungen (git status)."
# Nur main und Versions-Tags; der wandernde Tag "dev" der DEV-Builds (1.2.2) würde sonst stören.
git fetch --quiet origin main 'refs/tags/v*:refs/tags/v*'
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

step "Im Container: testen, bauen, signieren, prüfen"
docker compose exec -T dev ./scripts/release-build.sh "$VERSION" "$BUILD"
APK="dist/gymlog-$VERSION.apk"
SIGNING="dist/gymlog-$VERSION.signing"
[ -f "$APK" ] && [ -f "$SIGNING" ] || fail "Der Container hat keine APK geliefert."
CERT="$(sed -n 's/^cert=//p' "$SIGNING")"
DN="$(sed -n 's/^dn=//p' "$SIGNING")"
SHA="$(sha256 "$APK")"
[ -z "$(git status --porcelain)" ] || fail "Der Build hat Dateien im Repository verändert (git status)."

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
./scripts/release-notes.sh finalize "$VERSION" "$(date +%F)" >CHANGELOG.md.new
mv CHANGELOG.md.new CHANGELOG.md
git add CHANGELOG.md
if [ ! -f "$CERT_FILE" ]; then
  echo "$CERT" >"$CERT_FILE"
  git add "$CERT_FILE"
fi
git commit --quiet -m "chore(release): $TAG"
git tag -a "$TAG" -m "GymLog $VERSION"

step "Push nach GitHub"
if ! git push --atomic "$PUSH_URL" main "$TAG"; then
  echo >&2
  echo "Push fehlgeschlagen, auf GitHub hat sich nichts geändert. Lokal zurücksetzen und später neu starten:" >&2
  echo "  git tag -d $TAG && git reset --hard HEAD~1" >&2
  exit 1
fi

git fetch --quiet origin main || true

step "GitHub-Release anlegen (im Browser, etwa 1 Minute)"
# Titel und Tag stehen in der Adresse; der Text auch, solange die Adresse nicht zu lang wird.
SHORT_URL="https://github.com/$REPO/releases/new?tag=$TAG&title=GymLog%20$VERSION"
NEW_URL="$SHORT_URL"
BODY_IN_URL=no
if command -v python3 >/dev/null; then
  WITH_BODY="$SHORT_URL&body=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read()))' <"$NOTES")"
  # GitHub lehnt sehr lange Adressen ab; mit Sicherheitsabstand.
  if [ "${#WITH_BODY}" -le 6000 ]; then
    NEW_URL="$WITH_BODY"
    BODY_IN_URL=yes
  fi
fi
COPIED=no
if [ "$BODY_IN_URL" = no ]; then
  if command -v wl-copy >/dev/null && wl-copy <"$NOTES" 2>/dev/null; then COPIED=yes
  elif command -v xclip >/dev/null && xclip -selection clipboard <"$NOTES" 2>/dev/null; then COPIED=yes
  fi
fi
for opener in xdg-open wslview open; do
  if command -v "$opener" >/dev/null; then
    "$opener" "$NEW_URL" >/dev/null 2>&1 &
    break
  fi
done

echo "Commit und Tag $TAG sind auf GitHub. Jetzt im Browser (öffnet sich, sonst Link kopieren):"
echo
echo "  $SHORT_URL"
echo
if [ "$BODY_IN_URL" = yes ]; then
  echo "  1. Tag $TAG, Titel und Text sind schon ausgefüllt (im geöffneten Fenster)."
elif [ "$COPIED" = yes ]; then
  echo "  1. Text ist in der Zwischenablage: ins Beschreibungsfeld einfügen."
else
  echo "  1. Text ins Beschreibungsfeld kopieren aus: $(pwd)/$NOTES"
  echo "     (z. B. mit: cat $NOTES)"
fi
echo "  2. APK in das Feld \"Attach binaries\" ziehen: $(pwd)/$APK"
echo "  3. \"Set as the latest release\" angehakt lassen, \"Publish release\"."
echo
echo "Danach immer gültig zum Weitergeben: https://github.com/$REPO/releases/latest"
