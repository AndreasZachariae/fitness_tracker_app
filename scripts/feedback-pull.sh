#!/usr/bin/env bash
# Holt die Antworten des GymLog-Feedback-Formulars (1.8.0) als CSV nach docs/feedback/inbox.csv.
# Die Adresse der Antworttabelle steht in .local/feedback-csv-url (nicht im Repo, halb geheim: wer sie kennt,
# liest alle Antworten). docs/feedback/ ist ebenfalls in .gitignore – die Texte der Nutzer verlassen den Rechner nicht.
# Spricht nur Google an, nicht GitHub; Claude darf es im Container ausführen.
#
# Aufruf: ./scripts/feedback-pull.sh
set -euo pipefail
cd "$(dirname "$0")/.."

URL_FILE=".local/feedback-csv-url"
OUT_DIR="docs/feedback"
INBOX="$OUT_DIR/inbox.csv"
LAST="$OUT_DIR/last-processed.txt"

fail() { echo "Abbruch: $*" >&2; exit 1; }

[ -f "$URL_FILE" ] || fail "$URL_FILE fehlt (CSV-Adresse der Antworttabelle, eine Zeile)."
url="$(head -n 1 "$URL_FILE" | tr -d '[:space:]')"
case "$url" in
  https://docs.google.com/*) ;;
  *) fail "$URL_FILE enthält keine Google-Adresse." ;;
esac

mkdir -p "$OUT_DIR"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
code="$(curl -sSL --max-time 30 -o "$tmp" -w '%{http_code}' "$url")" || fail "Download fehlgeschlagen."
[ "$code" = 200 ] || fail "Google antwortete mit HTTP $code (Tabelle freigegeben: Jeder mit dem Link, Betrachter?)."
head -n 1 "$tmp" | grep -q '^Zeitstempel,' || fail "Unerwartetes Format (erste Zeile: $(head -c 80 "$tmp"))."
mv "$tmp" "$INBOX"
trap - EXIT

# Zählt Antworten (CSV mit Zeilenumbrüchen in Feldern) und die seit dem letzten verarbeiteten Zeitstempel.
python3 -I - "$INBOX" "$LAST" <<'PY'
import csv, sys, os
from datetime import datetime
rows = list(csv.DictReader(open(sys.argv[1], encoding='utf-8')))
def ts(s):
    for f in ('%d.%m.%Y %H:%M:%S', '%m/%d/%Y %H:%M:%S'):
        try: return datetime.strptime(s, f)
        except ValueError: pass
    return None
last = None
if os.path.exists(sys.argv[2]):
    last = ts(open(sys.argv[2], encoding='utf-8').read().strip())
new = [r for r in rows if last is None or (ts(r['Zeitstempel']) or datetime.max) > last]
print(f"{len(rows)} Antwort(en) insgesamt, {len(new)} neu"
      + ("" if last is None else f" seit {last:%d.%m.%Y %H:%M:%S}") + f" → {sys.argv[1]}")
for r in new:
    text = ' '.join(r['Beschreibung'].split())
    print(f"  {r['Zeitstempel']} · {r['Art']} · {r['App-Version']} ({r['Kanal']}): {text[:70]}{'…' if len(text) > 70 else ''}")
PY
