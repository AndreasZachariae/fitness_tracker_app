#!/usr/bin/env bash
# Version der DEV-App (1.2.2), für install-dev.sh, build-dev-apk.sh und release-dev.sh. Gibt zwei Zeilen aus:
#   1.2.2-dev.57     (Version aus pubspec.yaml + Anzahl der Commits)
#   100057           (versionCode: 100000 + Anzahl der Commits)
# Die Zahl steigt mit jedem Commit, so ersetzt jeder neue DEV-Build den alten – egal ob per Kabel oder über GitHub
# installiert. Die echte App (de.gymlog.app) nutzt weiter die Build-Nummer aus pubspec.yaml.
set -euo pipefail
cd "$(dirname "$0")/.."
count="$(git rev-list --count HEAD)"
version="$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)"
echo "$version-dev.$count"
echo "$((100000 + count))"
