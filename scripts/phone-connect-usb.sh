#!/usr/bin/env bash
# IM CONTAINER ausführen. Verbindet das Handy per USB-Kabel mit adb und prüft unterwegs alle typischen Hürden.
# Voraussetzung (einmalig): scripts/host-setup-usb.sh auf dem Host und die USB-Einträge in docker-compose.yml.
# Installiert nichts und berührt keine App.
set -euo pipefail

fail() {
  echo >&2
  echo "✗ $1" >&2
  shift
  for line in "$@"; do echo "  $line" >&2; done
  exit 1
}

echo "==> Suche Android-Geräte mit USB-Debugging"
[ -d /dev/bus/usb ] || fail "Im Container gibt es kein /dev/bus/usb." \
  "docker-compose.yml muss '/dev/bus/usb:/dev/bus/usb' unter volumes enthalten." \
  "Danach auf dem Host: docker compose up -d"

# adb-Schnittstelle = Klasse ff, Unterklasse 42, Protokoll 01
nodes=()
for intf in /sys/bus/usb/devices/*:*; do
  [ -f "$intf/bInterfaceClass" ] || continue
  if [ "$(cat "$intf/bInterfaceClass")/$(cat "$intf/bInterfaceSubClass")/$(cat "$intf/bInterfaceProtocol")" = "ff/42/01" ]; then
    dev="${intf%:*}"
    name="$(cat "$dev/manufacturer" 2>/dev/null || true) $(cat "$dev/product" 2>/dev/null || true)"
    node="$(printf '/dev/bus/usb/%03d/%03d' "$(cat "$dev/busnum")" "$(cat "$dev/devnum")")"
    echo "    gefunden: ${name# } ($node)"
    nodes+=("$node")
  fi
done

[ ${#nodes[@]} -gt 0 ] || fail "Kein Handy mit aktivem USB-Debugging am USB gefunden." \
  "- Kabel steckt? Manche Kabel können nur laden – anderes Kabel probieren." \
  "- Handy: Einstellungen > System > Entwickleroptionen > USB-Debugging einschalten." \
  "- Handy entsperren und die USB-Benachrichtigung prüfen (Modus 'Dateiübertragung' hilft manchmal)."

for node in "${nodes[@]}"; do
  [ -e "$node" ] || fail "Das Handy ist am Rechner, aber $node fehlt im Container." \
    "Der Container nutzt noch die alte Konfiguration ('devices:' sieht nur Geräte vom Startzeitpunkt)." \
    "Auf dem Host im Projektordner: docker compose up -d   (übernimmt die neue docker-compose.yml)"
  [ -r "$node" ] && [ -w "$node" ] || fail "Keine Zugriffsrechte auf $node ($(stat -c '%U:%G %a' "$node"))." \
    "Auf dem Host einmalig: ./scripts/host-setup-usb.sh" \
    "Danach USB-Kabel ab- und wieder anstecken und dieses Skript erneut starten."
done
echo "    Zugriffsrechte ok"

echo "==> Starte adb-Server neu"
adb kill-server >/dev/null 2>&1 || true
adb start-server >/dev/null 2>&1

echo "==> Warte auf das Handy (bis zu 30 s)"
state=""
for _ in $(seq 1 30); do
  state="$(adb devices | awk 'NR>1 && $1 !~ /:/ && NF>=2 {print $2; exit}')"
  case "$state" in
    device) break ;;
    unauthorized)
      [ "${asked:-}" ] || echo "    Bitte am Handy 'USB-Debugging zulassen?' bestätigen (Haken bei 'Immer von diesem Computer zulassen')."
      asked=1
      ;;
    "no permissions"* | no) fail "adb meldet 'no permissions'." "Auf dem Host: ./scripts/host-setup-usb.sh, dann Kabel neu anstecken." ;;
  esac
  sleep 1
done

[ "$state" = "device" ] || fail "Das Handy hat sich nicht verbunden (Status: ${state:-keiner})." \
  "- Läuft auf dem Host ein eigener adb-Server (Android Studio)? Auf dem Host: adb kill-server" \
  "- Am Handy: Entwickleroptionen > 'USB-Debugging-Autorisierungen widerrufen', Kabel neu anstecken, Skript erneut starten."

echo
adb devices -l

if [ "$(adb devices | awk 'NR>1 && NF>=2' | wc -l)" -gt 1 ]; then
  echo
  echo "Hinweis: Es sind mehrere Geräte verbunden (USB und WLAN). scripts/install-dev.sh braucht genau eins."
  echo "WLAN-Verbindung trennen mit: adb disconnect"
fi
echo
echo "✓ Handy per USB verbunden. Weiter mit ./scripts/install-dev.sh oder flutter run."
