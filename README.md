# GymLog

Private Android-App fürs Krafttraining: Pläne, Sätze, Pausentimer, Statistik, Körpergewicht, Backup.
Alles bleibt auf dem Handy, ohne Konto und ohne Internet. Entwickelt wird mit Flutter in einem Docker-Container
zusammen mit Claude Code.

| | |
|---|---|
| **GymLog** (blaues Icon) | die echte App fürs Studio, Paket `de.gymlog.app` |
| **GymLog DEV** (gelbes Icon) | Entwicklungsversion zum Ausprobieren, eigene Daten, Paket `de.gymlog.app.dev` |
| `docs/ROADMAP.md` | deine Ideen für neue Versionen |
| `CHANGELOG.md` | was sich in welcher Version geändert hat (wird zum Text der GitHub-Release) |
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
claude --resume                    # Claude Code mit dem letzten Gespräch fortsetzen (oder nur: claude)
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
3. Claude Code plant, setzt mit Tests um, erhöht die Version in `pubspec.yaml`, schreibt den Abschnitt in
   `CHANGELOG.md`, eine Testliste fürs Handy in `docs/PROGRESS.md`, setzt die Roadmap auf `FINISHED` und committet.
4. Testliste am Handy mit der DEV-App abarbeiten, dann auf dem PC veröffentlichen
   (siehe [Neue Version veröffentlichen](#neue-version-veröffentlichen-release)).

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

### Veröffentlichen auf GitHub

Siehe [Neue Version veröffentlichen](#neue-version-veröffentlichen-release) weiter unten.

### APK-Datei ohne Release

```bash
./scripts/build-release-apk.sh     # erzeugt dist/gymlog-<version>.apk, veröffentlicht nichts
```

Datei aufs Handy bringen, in der Dateien-App antippen und „Aus dieser Quelle zulassen“ erlauben. Warnt Play Protect
vor einem unbekannten Entwickler: „Trotzdem installieren“. Ein Update über eine neuere APK-Datei funktioniert genauso
und behält die Daten (gleicher Schlüssel).

### Daten schützen

- **GymLog nie deinstallieren** und nie „Speicher löschen“; das löscht alle Trainings.
- In der App unter Einstellungen → Daten regelmäßig **„Backup erstellen“** und die Datei extern sichern. Die App erinnert
  dich daran. „Backup wiederherstellen“ spielt es wieder ein (auch auf einem neuen Handy).
- „CSV exportieren“ liefert ein ZIP mit Tabellen für Excel oder Python.
- `.secrets/` (Signaturschlüssel) separat sichern, siehe oben.

---

## Neue Version veröffentlichen (Release)

Jede Version landet mit APK und Changelog unter
<https://github.com/AndreasZachariae/fitness_tracker_app/releases>. Zum Weitergeben an Freunde immer diesen Link
schicken, keine APK per Mail oder Teams: **<https://github.com/AndreasZachariae/fitness_tracker_app/releases/latest>**

Das Release startest **du auf dem PC** (nicht im Container): Gepusht wird mit deinem SSH-Schlüssel, der bei GitHub
hinterlegt ist. Der Container testet, baut und signiert nur und hat keinen Zugriff auf GitHub; Claude Code darf kein
Release auslösen. Kontrolle des SSH-Zugangs: `ssh -T git@github.com` („successfully authenticated“).

**Jedes Mal – Checkliste:**

1. Claude Code hat die Version umgesetzt: `pubspec.yaml` hat die neue Version, `CHANGELOG.md` einen Abschnitt
   `## [X.Y.Z] – unveröffentlicht`, alles ist committet.
2. Testliste in `docs/PROGRESS.md` mit der DEV-App am Handy abgearbeitet.
3. In `docs/ROADMAP.md` steht die Version auf `STATUS: FINISHED` (selbst setzen und committen, falls nötig).
4. Auf dem PC im Projektordner:

```bash
cd ~/pfad/zu/fitness_tracker_app   # Projektordner auf dem PC
docker compose up -d               # Container muss laufen
./scripts/release-notes.sh notes X.Y.Z   # optional: Release-Text vorab ansehen
./scripts/release.sh               # prüfen, bauen, Vorschau, nach "ja" veröffentlichen
```

`release.sh` prüft alles (GitHub-Login, Branch `main`, alles committet, Stand von GitHub, neue Version und
Build-Nummer, Roadmap `FINISHED`, Changelog), lässt im Container Tests laufen, die APK `dist/gymlog-X.Y.Z.apk` bauen
und signieren und vergleicht den Signaturschlüssel mit den bisherigen Releases. Dann zeigt es den Release-Text.
**Erst nach Eingabe von `ja`** trägt es Datum und Commits in `CHANGELOG.md` ein, committet, setzt den Tag `vX.Y.Z` und
pusht `main` und Tag per SSH. Jede andere Antwort bricht ab, ohne etwas zu ändern.

Zum Schluss öffnet es die Release-Seite im Browser mit Tag und Titel (und, wenn er kurz genug ist, dem Text). Dort:
Text einfügen, falls er fehlt (liegt in der Zwischenablage oder in `dist/release-notes-X.Y.Z.md`), die APK
`dist/gymlog-X.Y.Z.apk` in „Attach binaries“ ziehen, „Publish release“. Ein SSH-Schlüssel reicht nur für git, nicht
für GitHubs Release-Schnittstelle – so braucht es weder die GitHub CLI noch einen Token.

Gut zu wissen:
- Die APK enthält nur 64-Bit-ARM (~23 MB) und läuft auf praktisch jedem Handy ab Android 7.
- Freunde installieren wie in der Release beschrieben; mit [Obtainium](https://github.com/ImranR98/Obtainium) und der
  Repo-Adresse sehen sie neue Versionen automatisch.
- Danach die eigene GymLog-App aktualisieren: `./scripts/install-release.sh` (im Container) oder die APK aus der
  Release auf dem Handy installieren – die Daten bleiben.
- Das Repository ist öffentlich: Code, Doku und Commit-Verlauf sind sichtbar, `.secrets/` nicht.

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
| `scripts/release.sh` | **PC** | Version als GitHub-Release veröffentlichen (nur du) |
| `scripts/release-build.sh` | Container | wird von `release.sh` aufgerufen: testen, bauen, signieren, prüfen |
| `scripts/release-notes.sh` | PC oder Container | Vorschau/Prüfung von Changelog und Release-Text |
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
| `release.sh`: „Kein SSH-Zugang zu GitHub“ | `ssh -T git@github.com` prüfen; SSH-Schlüssel bei GitHub unter Settings → SSH keys hinterlegen. |
| `release.sh`: „läuft auf dem PC, nicht im Container“ | Terminal auf dem PC öffnen, im Projektordner starten. |
| `release.sh`: „ANDEREN Schlüssel“ | `.secrets/` aus der Sicherung zurückholen; niemals mit einem neuen Schlüssel veröffentlichen. |
| `release.sh`: Push fehlgeschlagen | Das Skript nennt den Befehl zum Zurücksetzen. |
| Release-Seite nicht geöffnet | Link aus der Ausgabe kopieren; Tag ist schon auf GitHub, die Release lässt sich jederzeit nachholen. |
| Skripte melden `\r`-Fehler (Windows) | Projekt im WSL-Dateisystem ablegen; `.gitattributes` erzwingt LF. |
