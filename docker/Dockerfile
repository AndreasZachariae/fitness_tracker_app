# GymLog Dev-Container: Flutter + Android SDK + JDK 17 + adb + Claude Code
#
# Basis: rootless Flutter-Android-Image (Debian, User "flutter" mit UID/GID 1001,
# Flutter- und Android-SDK unter /home/flutter/sdks, Gradle vorgewärmt).
# Quelle: https://github.com/gmeligio/flutter-docker-image
# Nur x86_64 (amd64).
FROM ghcr.io/gmeligio/flutter-android:3.47.9

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# UID/GID des Host-Users. Nur unter Linux (inkl. WSL2) relevant, damit Dateien im
# Projektordner dir gehören. Wird von scripts/setup-host.sh in .env geschrieben.
ARG HOST_UID=1001
ARG HOST_GID=1001

USER root

# sqlite: für drift-Tests auf Linux und zum Inspizieren der DB
# tzdata: lokale Zeitzone im Container
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libsqlite3-dev sqlite3 tzdata jq less nano zip procps \
    && rm -rf /var/lib/apt/lists/*

# User "flutter" auf Host-UID/GID umstellen, falls abweichend.
# Achtung: chown über die SDKs vergrößert das Image einmalig um einige GB.
RUN if [ "$HOST_UID" != "1001" ] || [ "$HOST_GID" != "1001" ]; then \
        groupmod -o -g "$HOST_GID" flutter \
        && usermod -o -u "$HOST_UID" -g "$HOST_GID" flutter \
        && chown -R flutter:flutter /home/flutter; \
    fi

USER flutter
ENV HOME=/home/flutter

# Verzeichnisse für die Volumes vorab anlegen, damit sie dem User gehören.
# Danach Claude Code installieren (nativer Installer, landet in ~/.local/bin).
RUN mkdir -p "$HOME/.claude" "$HOME/.pub-cache" "$HOME/.gradle" "$HOME/.android" "$HOME/.local/bin" \
    && git config --global --add safe.directory /workspace \
    && git config --global init.defaultBranch main \
    && curl -fsSL https://claude.ai/install.sh | bash

ENV PATH="/home/flutter/.local/bin:${PATH}" \
    CLAUDE_CONFIG_DIR=/home/flutter/.claude \
    PUB_CACHE=/home/flutter/.pub-cache \
    TZ=Europe/Berlin

WORKDIR /workspace
CMD ["sleep", "infinity"]
