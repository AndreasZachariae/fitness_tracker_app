#!/usr/bin/env bash
# Auf dem HOST ausführen (Linux oder WSL2), einmalig vor dem ersten "docker compose up".
# Legt .secrets/ an und schreibt deine UID/GID nach .env, damit Dateien im Projekt dir gehören.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p .secrets
chmod 700 .secrets

if [ "$(uname -s)" = "Linux" ]; then
  if [ ! -f .env ]; then
    printf 'HOST_UID=%s\nHOST_GID=%s\n' "$(id -u)" "$(id -g)" > .env
    echo ".env angelegt: HOST_UID=$(id -u), HOST_GID=$(id -g)"
  else
    echo ".env existiert bereits, unverändert."
  fi
else
  echo "Kein Linux erkannt – .env wird nicht benötigt (Docker Desktop regelt die Dateirechte)."
fi
chmod +x scripts/*.sh
echo "Fertig. Weiter mit: docker compose up -d --build"
