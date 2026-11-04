# GymLog

Private Android-App fürs Krafttraining: Pläne, Sätze, Pausentimer, Statistik, Körpergewicht, Backup.
Alles bleibt auf dem Handy, ohne Konto und ohne Internet. Entwickelt wird mit Flutter in einem Docker-Container
zusammen mit Claude Code.

| | |
|---|---|
| **GymLog** (blaues Icon) | die echte App fürs Studio, Paket `de.gymlog.app` |
| **GymLog DEV** (gelbes Icon) | Entwicklungsversion zum Ausprobieren, eigene Daten, Paket `de.gymlog.app.dev` |
| `docs/ROADMAP.md` | deine Ideen für neue Versionen |
| `docs/SPEC.md` | Spezifikation der App (Stand 1.0) |
| `docs/PROGRESS.md` | Annahmen, Entscheidungen, Testlisten fürs Handy |
| `CLAUDE.md` | Regeln für Claude Code |

---

## Einmalige Einrichtung

**Voraussetzungen:** PC mit Intel/AMD-Prozessor und Docker (Linux: Docker Engine + Compose, Windows/macOS: Docker
Desktop; unter Windows das Projekt im WSL2-Dateisystem ablegen und alle Befehle im WSL-Terminal ausführen),
Android-Handy (Android 11+), Claude-Abo mit Claude Code.

```bash
# auf dem PC, im Projektordner
./scripts/host-setup.sh            # legt .secrets/ und (Linux) .env mit deiner User-ID an
docker compose up -d --build       # beim ersten Mal 10–30 min
docker compose exec dev bash       # in den Container; alle weiteren Befehle laufen dort in /workspace
```

### Signaturschlüssel – wichtig

```bash
./scripts/create-keystore.sh       # einmalig, im Container
```

Android aktualisiert eine App nur, wenn das Update mit **demselben Schlüssel** signiert ist. Ohne diesen Schlüssel
lässt sich GymLog nur noch per Deinstallieren ersetzen, und **Deinstallieren löscht alle Trainingsdaten**.

- Den Ordner **`.secrets/` sofort an einem zweiten Ort sichern** (USB-Stick, Passwort-Manager). Er ist absichtlich
  nicht in git.
- Das Skript überschreibt einen vorhandenen Schlüssel nie. Keinen neuen erzeugen, sobald die App installiert ist.

### Handy vorbereiten

1. Einstellungen → Über das Telefon → 7× auf **Build-Nummer** tippen (schaltet die Entwickleroptionen frei).
2. Einstellungen → System → **Entwickleroptionen** → **USB-Debugging** (für Kabel) bzw. **Kabelloses Debugging**
   (für WLAN) einschalten.

### Nur für USB, nur Linux-PC

```bash
./scripts/host-setup-usb.sh        # auf dem PC (nicht im Container), fragt nach dem sudo-Passwort
```

Danach Kabel ab- und wieder anstecken und `docker compose up -d`. Unter Windows/macOS geht nur WLAN; dann in
`docker-compose.yml` die Zeile `/dev/bus/usb…` und den Block `device_cgroup_rules` auskommentieren.

---

## Weiterentwickeln (jedes Mal)

```bash
docker compose up -d               # auf dem PC: Container starten
docker compose exec dev bash       # in den Container
claude --continue                  # Claude Code mit dem letzten Gespräch fortsetzen (oder nur: claude)
```

### Handy verbinden – Option A: USB-Kabel (Linux)

```bash
./scripts/phone-connect-usb.sh
```

Handy entsperren und „USB-Debugging zulassen?“ bestätigen. Das Skript erklärt bei Problemen, was fehlt.

### Handy verbinden – Option B: WLAN

```bash
./scripts/phone-connect-wifi.sh
```

Handy und PC im selben WLAN, auf dem Handy „Kabelloses Debugging“ öffnen. Beim ersten Mal koppeln: „Gerät über
Kopplungscode koppeln“, IP:Port und Code eingeben. Danach IP:Port vom **Hauptbildschirm** „Kabelloses Debugging“
eingeben (ein anderer Port als beim Koppeln). Nach Neustart von Handy oder Container nur noch verbinden.

Kontrolle in beiden Fällen: `adb devices` zeigt das Gerät mit `device`.

### DEV-App aufs Handy

```bash
./scripts/install-dev.sh           # bauen, installieren, starten
flutter run                        # alternativ mit Live-Vorschau: r = neu laden, R = neu starten, q = beenden
```

In der DEV-App gibt es unter Einstellungen → „Entwicklung (nur GymLog DEV)“ „Demo-Daten erzeugen“ und „Alle Daten löschen“.

### Neue Funktionen: über `docs/ROADMAP.md`

1. Ideen unter einer Versionsnummer in `docs/ROADMAP.md` eintragen, Status `PLANNED`.
2. Claude Code beauftragen, zum Beispiel:
   ```
   Lies docs/ROADMAP.md. Setze jetzt Version 1.1.0 um.
   ```
3. Claude Code plant, setzt mit Tests um, committet und schreibt eine Testliste fürs Handy in `docs/PROGRESS.md`.
4. Testliste am Handy mit der DEV-App abarbeiten; danach steht die Version in der Roadmap auf `FINISHED`.

Ohne diesen Auftrag setzt Claude Code nichts aus der Roadmap um.

### Container stoppen

```bash
docker compose down                # auf dem PC; NICHT "down -v" (löscht Claude-Login, Gesprächsverlauf und Caches)
```

---

## Die echte App (GymLog)

### Aufs eigene Handy installieren oder aktualisieren

```bash
./scripts/install-release.sh       # Handy vorher verbinden (USB oder WLAN)
```

Updates behalten alle Daten. Dieses Skript führst du selbst aus, Claude Code darf es nicht.

### APK-Datei zum Weitergeben oder ohne Verbindung installieren

```bash
./scripts/build-release-apk.sh     # erzeugt dist/gymlog-<version>.apk
```

Datei per Kabel, Cloud oder Mail aufs Handy bringen, in der Dateien-App antippen und „Aus dieser Quelle zulassen“
erlauben. Warnt Play Protect vor einem unbekannten Entwickler: „Trotzdem installieren“. Ein Update über eine neuere
APK-Datei funktioniert genauso und behält die Daten (gleicher Schlüssel).

### Daten schützen

- **GymLog nie deinstallieren** und nie „Speicher löschen“; das löscht alle Trainings.
- In der App unter Einstellungen → Daten regelmäßig **„Backup erstellen“** und die Datei extern sichern. Die App erinnert
  dich daran. „Backup wiederherstellen“ spielt es wieder ein (auch auf einem neuen Handy).
- „CSV exportieren“ liefert ein ZIP mit Tabellen für Excel oder Python.
- `.secrets/` (Signaturschlüssel) separat sichern, siehe oben.

---

## Alle Skripte

| Skript | Wo | Wozu |
|---|---|---|
| `scripts/host-setup.sh` | PC | einmalig: `.secrets/` und `.env` anlegen |
| `scripts/host-setup-usb.sh` | PC (Linux) | einmalig: USB-Zugriff für den Container erlauben |
| `scripts/create-keystore.sh` | Container | einmalig: Signaturschlüssel erzeugen |
| `scripts/phone-connect-usb.sh` | Container | Handy per USB verbinden |
| `scripts/phone-connect-wifi.sh` | Container | Handy per WLAN koppeln/verbinden |
| `scripts/install-dev.sh` | Container | DEV-App bauen, installieren, starten |
| `scripts/install-release.sh` | Container | echte App installieren/aktualisieren |
| `scripts/build-release-apk.sh` | Container | echte App als APK-Datei nach `dist/` |
| `scripts/check.sh` | Container | Formatierung, Analyse, alle Tests |
| `scripts/screenshot.sh` | Container | Screenshot vom Handy nach `build/screenshots/` |

## Probleme

| Problem | Lösung |
|---|---|
| `adb devices` zeigt nichts | USB: Kabel/Debugging prüfen, `./scripts/phone-connect-usb.sh` erneut. WLAN: gleiches Netz? Kabelloses Debugging noch an? `./scripts/phone-connect-wifi.sh` erneut. |
| Gerät steht auf `unauthorized` | Handy entsperren und Abfrage bestätigen. |
| USB und WLAN gleichzeitig verbunden | `install-dev.sh` braucht genau ein Gerät: `adb disconnect` trennt WLAN. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Die installierte App hat einen anderen Schlüssel. **Nicht deinstallieren**, erst in der App ein Backup erstellen und sichern; dann deinstallieren, neu installieren, Backup wiederherstellen. |
| Dateien gehören plötzlich „1001“ oder root (Linux) | `./scripts/host-setup.sh`, dann `docker compose build --no-cache && docker compose up -d`. |
| „Permission denied“ in Caches nach Änderung von `.env` | `docker compose down -v` (löscht Caches und Claude-Login, nicht `.secrets/`), dann neu bauen. |
| Skripte melden `\r`-Fehler (Windows) | Projekt im WSL-Dateisystem ablegen; `.gitattributes` erzwingt LF. |
