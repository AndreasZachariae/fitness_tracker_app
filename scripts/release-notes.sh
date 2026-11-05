#!/usr/bin/env bash
# IM CONTAINER ausführen. Erzeugt Changelog-Teile und den Text einer GitHub-Release. Liest nur, ändert nichts,
# braucht weder Schlüssel noch Internet.
#
#   ./scripts/release-notes.sh check   <version>   prüft den Abschnitt "## [<version>] – unveröffentlicht" in CHANGELOG.md
#   ./scripts/release-notes.sh commits             Commit-Liste seit dem letzten Release-Tag (Markdown)
#   ./scripts/release-notes.sh notes   <version>   kompletter Release-Text (Vorschau), wie ihn scripts/release.sh nutzt
#   ./scripts/release-notes.sh finalize <version> <datum>   gibt CHANGELOG.md mit Datum und Commit-Liste aus (schreibt nicht)
set -euo pipefail
cd "$(dirname "$0")/.."

CHANGELOG="CHANGELOG.md"
FOOTER=".github/release-footer.md"
REPO_URL="https://github.com/AndreasZachariae/fitness_tracker_app"

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

# Text des Abschnitts einer Version ohne Überschrift, ohne Leerzeilen am Anfang und Ende.
section_body() {
  awk -v v="$1" '
    index($0, "## [" v "]") == 1 { inside = 1; next }
    inside && /^## \[/ { exit }
    inside { print }
  ' "$CHANGELOG" | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}'
}

section_header() {
  grep -m1 -F "## [$1]" "$CHANGELOG" || true
}

last_tag() {
  git describe --tags --abbrev=0 --match 'v[0-9]*' HEAD 2>/dev/null || true
}

# Markdown-Liste der Commits seit dem letzten Release-Tag, nach Conventional-Commit-Typ gruppiert.
commit_block() {
  local tag range title
  tag="$(last_tag)"
  if [ -n "$tag" ]; then
    range="$tag..HEAD"
    title="Commits seit $tag (für Entwickler)"
  else
    range="HEAD"
    title="Alle Commits (für Entwickler)"
  fi
  local list
  list="$(git log --no-merges --reverse --format='%h%x09%s' "$range" | awk -F'\t' '
    BEGIN {
      n = split("feat fix perf refactor docs test build ci chore style other", order, " ")
      name["feat"] = "Features"; name["fix"] = "Fehlerbehebungen"; name["perf"] = "Performance"
      name["refactor"] = "Refactoring"; name["docs"] = "Dokumentation"; name["test"] = "Tests"
      name["build"] = "Build"; name["ci"] = "CI"; name["chore"] = "Wartung"; name["style"] = "Formatierung"
      name["other"] = "Sonstiges"
    }
    {
      hash = $1; subject = $2
      if (subject ~ /^chore\(release\)/) next
      type = "other"; text = subject
      if (match(subject, /^[a-z]+(\([^)]*\))?!?: /)) {
        t = substr(subject, 1, RLENGTH)
        sub(/(\([^)]*\))?!?: $/, "", t)
        if (t in name) { type = t; text = substr(subject, RLENGTH + 1) }
      }
      items[type] = items[type] "- " text " (`" hash "`)\n"
    }
    END {
      for (i = 1; i <= n; i++) {
        t = order[i]
        if (t in items) printf "#### %s\n%s\n", name[t], items[t]
      }
    }
  ')"
  if [ -z "$list" ]; then
    list="Keine Commits."
  fi
  printf '<details>\n<summary>%s</summary>\n\n%s\n\n</details>\n' "$title" "$list"
}

check() {
  local v="$1" header body
  header="$(section_header "$v")"
  if [ -z "$header" ]; then
    echo "CHANGELOG.md hat keinen Abschnitt \"## [$v] – unveröffentlicht\"." >&2
    return 1
  fi
  if [[ "$header" != *"unveröffentlicht"* ]]; then
    echo "Version $v ist laut CHANGELOG.md schon veröffentlicht: $header" >&2
    return 1
  fi
  body="$(section_body "$v")"
  if [ -z "$body" ]; then
    echo "Der Abschnitt [$v] in CHANGELOG.md ist leer." >&2
    return 1
  fi
}

notes() {
  local v="$1" body
  body="$(section_body "$v")"
  if [ -z "$body" ]; then
    echo "Kein Abschnitt [$v] in CHANGELOG.md." >&2
    return 1
  fi
  printf '%s\n' "$body"
  # Vor dem Release steht die Commit-Liste noch nicht im Changelog.
  if [[ "$body" != *"<details>"* ]]; then
    printf '\n'
    commit_block
  fi
  printf '\n'
  sed -e "s|{{APK}}|gymlog-$v.apk|g" -e "s|{{REPO_URL}}|$REPO_URL|g" "$FOOTER"
}

# CHANGELOG.md mit veröffentlichtem Abschnitt: Datum statt "unveröffentlicht", Commit-Liste am Ende des Abschnitts.
finalize() {
  local v="$1" date="$2" block_file
  check "$v"
  block_file="$(mktemp)"
  commit_block > "$block_file"
  awk -v v="$v" -v d="$date" -v bf="$block_file" '
    function block(  line) {
      while ((getline line < bf) > 0) print line
      close(bf)
    }
    index($0, "## [" v "]") == 1 { print "## [" v "] – " d; inside = 1; next }
    inside && /^## \[/ { block(); print ""; inside = 0 }
    { print }
    END { if (inside) { print ""; block() } }
  ' "$CHANGELOG"
  rm -f "$block_file"
}

case "${1:-}" in
  check) [ $# -eq 2 ] || usage; check "$2" ;;
  commits) [ $# -eq 1 ] || usage; commit_block ;;
  notes) [ $# -eq 2 ] || usage; notes "$2" ;;
  finalize) [ $# -eq 3 ] || usage; finalize "$2" "$3" ;;
  *) usage ;;
esac
