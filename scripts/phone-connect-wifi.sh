#!/usr/bin/env bash
# IM CONTAINER ausführen. Verbindet das Handy per WLAN (Android 11+, "Kabelloses Debugging").
set -euo pipefail

# Nur im Container: Auf dem PC läuft oft ein altes adb (ohne "pair") oder ein zweiter adb-Server.
if [ ! -f /.dockerenv ]; then
  echo "Dieses Skript läuft im Container, nicht auf dem PC. Erst:" >&2
  echo "  docker compose up -d && docker compose exec dev bash" >&2
  echo "dann dort: ./scripts/$(basename "$0")" >&2
  exit 1
fi

fail() {
  echo >&2
  echo "✗ $1" >&2
  shift
  for line in "$@"; do echo "  $line" >&2; done
  exit 1
}

CAUSES=(
  "Häufigste Ursachen:"
  "- Dialog oder Display am Handy war inzwischen zu: Port und Code gelten nur, solange der Dialog offen ist."
  "- Falscher Port: Koppeln nutzt den Port aus dem Dialog 'Gerät über Kopplungscode koppeln',"
  "  Verbinden den (anderen) Port vom Hauptbildschirm 'Kabelloses Debugging'."
  "- Handy und PC nicht im selben WLAN, Gäste-WLAN/Client-Isolation am Router, VPN auf PC oder Handy."
  "- Code vertippt."
  "Dann: Dialog am Handy neu öffnen (neuer Port und Code) und das Skript erneut starten."
  "Alternative: Kabel und ./scripts/phone-connect-usb.sh"
)

# "IP:Port" einlesen; mit check=yes vorab prüfen, ob dort jemand lauscht (3 s), denn adb meldet sonst
# nur "protocol fault (couldn't read status message)". Den Kopplungsport nicht vorab prüfen: eine
# leere Verbindung könnte am Handy als fehlgeschlagener Kopplungsversuch zählen.
ask_addr() {
  local prompt="$1" check="$2" addr host port
  read -rp "$prompt" addr
  addr="${addr// /}"
  [[ "$addr" =~ ^([0-9]{1,3}(\.[0-9]{1,3}){3}):([0-9]{1,5})$ ]] ||
    fail "\"$addr\" ist keine Adresse der Form 192.168.1.23:37123."
  host="${BASH_REMATCH[1]}"
  port="${BASH_REMATCH[3]}"
  if [ "$check" = yes ] && ! timeout 3 bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null; then
    fail "$host:$port ist vom Container aus nicht erreichbar." "${CAUSES[@]}"
  fi
  REPLY_ADDR="$addr"
}

echo "Handy: Einstellungen > Entwickleroptionen > Kabelloses Debugging einschalten, Bildschirm offen lassen."
echo
read -rp "Erstes Mal mit diesem Container koppeln? [j/N] " ans
if [[ "${ans,,}" == "j" ]]; then
  echo "Auf dem Handy: 'Gerät über Kopplungscode koppeln' antippen und den Dialog offen lassen."
  ask_addr "IP-Adresse und Port AUS DEM KOPPLUNGSDIALOG (z.B. 192.168.1.23:37123): " no
  pair_addr="$REPLY_ADDR"
  read -rp "Sechsstelliger Kopplungscode: " pair_code
  if ! adb pair "$pair_addr" "${pair_code// /}"; then
    fail "Koppeln fehlgeschlagen (\"protocol fault\" heißt meist: Handy unter dieser Adresse nicht erreichbar)." \
      "${CAUSES[@]}"
  fi
  echo
fi

echo "Jetzt den Hauptbildschirm 'Kabelloses Debugging' öffnen (nicht den Kopplungsdialog)."
ask_addr "IP-Adresse und Port vom HAUPTBILDSCHIRM 'Kabelloses Debugging' (z.B. 192.168.1.23:41567): " yes
adb connect "$REPLY_ADDR"
echo
adb devices -l
