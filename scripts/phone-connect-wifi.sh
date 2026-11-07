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

echo "Handy: Einstellungen > Entwickleroptionen > Kabelloses Debugging / Debugging über WLAN (einschalten, Bildschirm offen lassen)"
echo
read -rp "Erstes Mal mit diesem Container koppeln? [j/N] " ans
if [[ "${ans,,}" == "j" ]]; then
  echo "Auf dem Handy: 'Gerät über Kopplungscode koppeln' antippen."
  read -rp "IP-Adresse und Port AUS DEM KOPPLUNGSDIALOG (z.B. 192.168.1.23:37123): " pair_addr
  read -rp "Sechsstelliger Kopplungscode: " pair_code
  adb pair "$pair_addr" "$pair_code"
  echo
fi

read -rp "IP-Adresse und Port vom HAUPTBILDSCHIRM 'Kabelloses Debugging' (z.B. 192.168.1.23:41567): " addr
adb connect "$addr"
echo
adb devices -l
