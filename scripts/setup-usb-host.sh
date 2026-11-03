#!/usr/bin/env bash
# Auf dem HOST ausführen (Linux), einmalig. Erlaubt dem Dev-Container den Zugriff auf Android-Handys per USB.
#
# Legt eine udev-Regel an: Jedes USB-Gerät mit adb-Schnittstelle (USB-Debugging an) gehört danach deiner
# Benutzergruppe. Der User "flutter" im Container hat dieselbe GID (siehe .env), darf also darauf zugreifen.
# Braucht sudo. Ändert nichts am Handy.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(uname -s)" != "Linux" ] || grep -qi microsoft /proc/version 2>/dev/null; then
  echo "USB-Debugging im Container wird nur auf einem Linux-Host unterstützt (nicht WSL/Windows/macOS)." >&2
  echo "Nutze stattdessen WLAN: ./scripts/connect-phone.sh im Container." >&2
  exit 1
fi
if [ "$(id -u)" = "0" ]; then
  echo "Bitte als normaler User ausführen (nicht mit sudo) – das Skript fragt selbst nach dem Passwort." >&2
  exit 1
fi

GROUP_NAME="$(id -gn)"
GROUP_ID="$(id -g)"
if [ -f .env ]; then
  ENV_GID="$(sed -n 's/^HOST_GID=//p' .env)"
  if [ -n "$ENV_GID" ] && [ "$ENV_GID" != "$GROUP_ID" ]; then
    echo "Achtung: Deine GID ist $GROUP_ID, in .env steht HOST_GID=$ENV_GID." >&2
    echo "Der Container-User hätte dann keinen Zugriff. Erst .env korrigieren und den Container neu bauen." >&2
    exit 1
  fi
fi

RULE_FILE=/etc/udev/rules.d/51-gymlog-adb.rules
RULE='SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{ID_USB_INTERFACES}=="*:ff4201:*", MODE="0660", GROUP="'"$GROUP_NAME"'"'

echo "Schreibe $RULE_FILE (Gruppe: $GROUP_NAME, GID $GROUP_ID) …"
printf '%s\n%s\n%s\n' \
  "# GymLog-Dev-Container: Android-Geräte mit USB-Debugging (adb-Schnittstelle ff/42/01)" \
  "# für die Gruppe des Entwickler-Users freigeben. Angelegt von scripts/setup-usb-host.sh." \
  "$RULE" | sudo tee "$RULE_FILE" >/dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --action=change

# Ein adb-Server auf dem Host würde das Handy exklusiv belegen.
if pgrep -x adb >/dev/null 2>&1; then
  echo
  echo "Auf dem Host läuft ein adb-Server (z. B. von Android Studio). Er blockiert das Handy für den Container."
  if command -v adb >/dev/null 2>&1; then
    adb kill-server || true
    echo "adb-Server auf dem Host beendet."
  else
    echo "Bitte beenden: pkill -x adb"
  fi
fi

echo
echo "Fertig. Jetzt:"
echo "  1. USB-Kabel einmal ab- und wieder anstecken."
echo "  2. Container mit der neuen docker-compose.yml starten: docker compose up -d"
echo "  3. Im Container: ./scripts/connect-usb.sh"
