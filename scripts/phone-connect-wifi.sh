#!/usr/bin/env bash
# IM CONTAINER ausführen. Verbindet das Handy per WLAN (Android 11+, "Kabelloses Debugging").
set -euo pipefail

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
