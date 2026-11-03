#!/usr/bin/env bash
# IM CONTAINER ausführen. Baut die ECHTE App (de.gymlog.app) und installiert bzw. aktualisiert sie.
# Deine Trainingsdaten bleiben erhalten (adb install -r).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .secrets/key.properties ]; then
  echo "Kein Signaturschlüssel gefunden. Erst ./scripts/create-keystore.sh ausführen (README, Schritt 4)." >&2
  exit 1
fi
if ! adb get-state >/dev/null 2>&1; then
  echo "Kein Handy verbunden. Erst ./scripts/connect-phone.sh ausführen." >&2
  exit 1
fi

flutter build apk --release
APK="build/app/outputs/flutter-apk/app-release.apk"

if ! adb install -r "$APK"; then
  echo >&2
  echo "Installation fehlgeschlagen." >&2
  echo "Steht oben INSTALL_FAILED_UPDATE_INCOMPATIBLE: Die App auf dem Handy wurde mit einem anderen" >&2
  echo "Schlüssel signiert. NICHT deinstallieren, bevor du in der App ein Backup erstellt hast (README, Abschnitt 'Probleme')." >&2
  exit 1
fi
echo "GymLog ist installiert/aktualisiert."
