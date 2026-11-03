#!/usr/bin/env bash
# IM CONTAINER ausführen, einmalig. Erzeugt den Signaturschlüssel der echten App.
# Ohne diesen Schlüssel kannst du die App später nie mehr aktualisieren, ohne die Daten zu verlieren.
set -euo pipefail
cd "$(dirname "$0")/.."

SECRETS=.secrets
KS="$SECRETS/release.jks"
PROPS="$SECRETS/key.properties"

if [ -f "$KS" ]; then
  echo "Es gibt bereits einen Schlüssel ($KS). Nichts zu tun – niemals überschreiben."
  exit 0
fi

mkdir -p "$SECRETS"
chmod 700 "$SECRETS"

PW="$(head -c 48 /dev/urandom | base64 | tr -d '+/=\n' | cut -c1-32)"
KEYTOOL="$(command -v keytool || echo "$JAVA_HOME/bin/keytool")"

"$KEYTOOL" -genkeypair -noprompt \
  -keystore "$KS" -storetype PKCS12 \
  -alias gymlog -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass "$PW" -keypass "$PW" \
  -dname "CN=GymLog, O=Private, C=DE"

cat > "$PROPS" <<PROPS_EOF
storeFile=release.jks
storePassword=$PW
keyAlias=gymlog
keyPassword=$PW
PROPS_EOF

chmod 600 "$KS" "$PROPS"
echo
echo "Signaturschlüssel erstellt: $KS"
echo "WICHTIG: Sichere den kompletten Ordner .secrets/ an einem zweiten Ort (USB-Stick, Passwort-Manager)."
