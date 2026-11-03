# GymLog

Deine private Trainings-App für Android: Pläne abarbeiten, Sätze erfassen, Fortschritt sehen, Daten exportieren.
Alles bleibt auf deinem Handy. Entwickelt wird mit Flutter, komplett in einem Docker-Container, umgesetzt von Claude Code.

Diese Anleitung setzt keine Android-Erfahrung voraus.

---

## Überblick: Was passiert hier?

- Auf deinem **PC** läuft ein Docker-Container mit allem, was man zum Bauen der App braucht (Flutter, Android SDK, Java, adb,
  Claude Code). Auf dem PC selbst installierst du nur Docker.
- **Claude Code** schreibt die App im Container, Meilenstein für Meilenstein, nach `CLAUDE.md` und `docs/SPEC.md`.
- Dein **Handy** verbindet sich per WLAN mit dem Container. Darauf gibt es zwei Apps:
  - **GymLog DEV** – die Entwicklungsversion zum Ausprobieren, mit eigenen Testdaten.
  - **GymLog** – die echte App fürs Studio mit deinen echten Daten.
- Die installierte App braucht danach weder PC noch WLAN.

## 1. Voraussetzungen

- PC mit **x86_64-Prozessor** (Intel/AMD) und ca. **20 GB freiem Speicher**. Apple-Silicon-Macs werden vom verwendeten Image nicht unterstützt.
- **Docker:** unter Linux Docker Engine mit Compose-Plugin, unter Windows/macOS Docker Desktop.
  Unter Windows den Projektordner **im WSL2-Dateisystem** ablegen (z. B. `~/gymlog` in Ubuntu-WSL), nicht unter `C:\` – das ist
  deutlich schneller und vermeidet Rechteprobleme. Alle Befehle dann im WSL-Terminal.
- **Android-Handy mit Android 11 oder neuer**, im selben WLAN wie der PC.
- Ein **Claude-Abo mit Claude Code** (Pro, Max, Team oder Enterprise) oder ein Console-Konto.
- Empfohlen: `git` auf dem PC, damit du jede Änderung nachvollziehen kannst.

## 2. Projekt einrichten (auf dem PC)

```bash
cd gymlog
git init                      # empfohlen: Claude Code committet nach jedem Meilenstein
./scripts/setup-host.sh       # legt .secrets/ an, unter Linux/WSL zusätzlich .env mit deiner User-ID
```

Falls „Permission denied“ erscheint: `chmod +x scripts/*.sh` und nochmal.

## 3. Container bauen und starten

```bash
docker compose up -d --build
```

Beim ersten Mal lädt Docker mehrere GB und baut das Image – je nach Leitung 10–30 Minuten.
Unter Linux mit einer User-ID ungleich 1001 wird das Image einmalig noch größer, weil die SDKs auf deinen User umgeschrieben werden.

In den Container wechseln:

```bash
docker compose exec dev bash
```

Du bist jetzt im Ordner `/workspace` – das ist dein Projektordner. Alles, was dort entsteht, siehst du auch auf dem PC.
Test: `flutter --version` und `claude --version` sollten Versionsnummern ausgeben.

**Alternative mit VS Code:** Erweiterung „Dev Containers“ installieren, Projektordner öffnen, „Reopen in Container“ wählen.
Das Terminal in VS Code läuft dann automatisch im Container.

## 4. Signaturschlüssel erzeugen (einmalig, im Container)

```bash
./scripts/create-keystore.sh
```

Warum: Android installiert ein Update nur, wenn es mit **demselben Schlüssel** signiert ist wie die installierte App.
Geht der Schlüssel verloren, kannst du die App nicht mehr aktualisieren, ohne sie zu deinstallieren – und Deinstallieren löscht alle Daten.

**Sichere jetzt den Ordner `.secrets/`** (USB-Stick, Passwort-Manager, verschlüsseltes Cloud-Backup). Er wird absichtlich nicht in git aufgenommen.

## 5. Claude Code starten (im Container)

```bash
claude
```

Beim ersten Start meldest du dich an: Claude Code zeigt einen Link. Öffne ihn im Browser auf dem PC, melde dich an.
Wird die Anmeldung nicht automatisch übernommen, kopiere den angezeigten Code und füge ihn im Terminal ein.
Der Login bleibt im Docker-Volume gespeichert. Den Ordner bestätigst du beim ersten Start als vertrauenswürdig – erst dann gelten
die vorbereiteten Freigaben aus `.claude/settings.json`.

Erster Auftrag:

```
Lies CLAUDE.md, docs/SPEC.md und docs/PROGRESS.md. Setze Meilenstein M0 um.
```

Claude Code stoppt nach jedem Meilenstein und sagt dir, was du am Handy testen sollst. Danach einfach:

```
Weiter mit M1.
```

Tipps:
- Für große Meilensteine (M3, M7) vorher in den Planmodus wechseln (`Shift+Tab`), den Plan prüfen, dann umsetzen lassen.
- `docs/PROGRESS.md` zeigt jederzeit den Stand, die getroffenen Annahmen und die Testlisten.
- Änderungswünsche an der App: zuerst in `docs/SPEC.md` eintragen (oder Claude bitten, das zu tun), dann umsetzen lassen.

## 6. Handy vorbereiten (einmalig)

**Entwickleroptionen freischalten**
1. Einstellungen → **Über das Telefon** → siebenmal auf **Build-Nummer** tippen.
   Bei Samsung: Einstellungen → Telefoninfo → Softwareinformationen → Buildnummer.
2. Ggf. PIN eingeben. Es erscheint „Sie sind jetzt Entwickler“.

**Kabelloses Debugging einschalten**
1. Einstellungen → System → **Entwickleroptionen** (bei Samsung direkt unter Einstellungen, ganz unten).
2. **Kabelloses Debugging** einschalten (je nach Hersteller auch „Debugging über WLAN“ oder „Wireless debugging“) und das
   aktuelle WLAN bestätigen.
3. Auf den Namen des Eintrags tippen (nicht nur auf den Schalter) – dieser Bildschirm zeigt **IP-Adresse und Port**.

## 7. Handy mit dem Container verbinden

Im Container:

```bash
./scripts/connect-phone.sh
```

- Beim ersten Mal „j“ für Koppeln wählen. Auf dem Handy **„Gerät über Kopplungscode koppeln“** (Wortlaut kann abweichen) antippen und die dort angezeigte
  IP:Port und den sechsstelligen Code eingeben.
- Danach fragt das Skript nach IP:Port vom **Hauptbildschirm** „Kabelloses Debugging“. Achtung: Das ist ein **anderer Port** als
  beim Koppeln.
- Erfolg: Die Liste am Ende zeigt dein Gerät mit `device`.

Koppeln ist nur einmal nötig. Nach einem Neustart des Handys oder des Containers ändert sich der Port – dann nur das Skript erneut
ausführen und das Koppeln überspringen.

**Linux-Alternative per USB-Kabel:** In `docker-compose.yml` den `devices`-Block einkommentieren, Container neu starten
(`docker compose up -d`), auf dem Handy „USB-Debugging“ aktivieren und die Abfrage bestätigen.

## 8. Entwickeln mit Live-Vorschau (DEV-App)

```bash
flutter run
```

Installiert **GymLog DEV** und startet sie. Im Terminal:
`r` = Änderungen sofort übernehmen (Hot Reload), `R` = App neu starten, `q` = beenden.
Die DEV-App hat eigene Daten. Probier darin alles aus – auch „Demo-Daten erzeugen“ in den Einstellungen.

Claude Code kann die DEV-App selbst installieren und Screenshots ansehen, solange das Handy verbunden ist.

## 9. Die echte App installieren und aktualisieren

```bash
./scripts/install-release.sh
```

Installiert bzw. aktualisiert **GymLog**. Deine Trainingsdaten bleiben bei Updates erhalten.
Beim ersten Mal fragt Google Play Protect evtl., ob die App gescannt werden soll – bestätigen.

**Ohne Debug-Verbindung** (z. B. für ein zweites Gerät):

```bash
flutter build apk --release
```

Die Datei `build/app/outputs/flutter-apk/app-release.apk` per Kabel, Cloud oder Mail aufs Handy bringen, in der Dateien-App antippen
und **„Aus dieser Quelle zulassen“** erlauben. Warnt Play Protect vor einem unbekannten Entwickler: Das bist du –
„Trotzdem installieren“ (Wortlaut je nach Hersteller).

## 10. Deine Daten schützen

- **Niemals die App GymLog deinstallieren** und nie „Speicher löschen“ in den App-Einstellungen – das löscht alle Trainings.
- In der App unter Einstellungen → Daten regelmäßig **„Backup erstellen“** und die Datei in Drive, Nextcloud o. Ä. sichern.
  Die App erinnert dich, wenn das letzte Backup zu alt ist.
- Für Auswertungen am PC: **„CSV exportieren“** liefert ein ZIP mit `sets.csv`, `sessions.csv`, `body_weight.csv`, `exercises.csv`
  (Komma-getrennt, Dezimalpunkt; in Python direkt mit `pandas.read_csv`, in Excel über Daten → Aus Text/CSV).
- Den Ordner `.secrets/` (Signaturschlüssel) separat sichern.

## Probleme

| Problem | Lösung |
|---|---|
| `adb devices` zeigt nichts | Kabelloses Debugging auf dem Handy noch an? Gleiches WLAN? `./scripts/connect-phone.sh` erneut ausführen. |
| Gerät steht auf `unauthorized` | Handy entsperren und die Abfrage bestätigen; ggf. neu koppeln. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Die installierte App hat einen anderen Signaturschlüssel. **Nicht deinstallieren.** Erst in der App ein Backup erstellen und sichern. Dann deinstallieren, neu installieren, Backup wiederherstellen. |
| Dateien im Projekt gehören plötzlich „1001“ oder root (Linux) | `.env` fehlt oder ist falsch: `./scripts/setup-host.sh`, dann `docker compose build --no-cache && docker compose up -d`. |
| „Permission denied“ in Caches nach Änderung von `.env` | Die Volumes gehören noch der alten User-ID: `docker compose down -v` (löscht Caches und Claude-Login, nicht deine App-Daten und nicht `.secrets/`), dann neu bauen. |
| Erster Build dauert sehr lange | Normal; Gradle lädt beim ersten Mal viele Abhängigkeiten. Danach liegen sie im Volume. |
| Skripte laufen unter Windows nicht (`\r`-Fehler) | Zeilenenden sind CRLF geworden. Projekt im WSL-Dateisystem ablegen; `.gitattributes` erzwingt LF bei git-Checkouts. |

## Projektstruktur

```
CLAUDE.md                 Regeln und Arbeitsweise für Claude Code
docs/SPEC.md              Vollständige Spezifikation der App
docs/PROGRESS.md          Fortschritt, Annahmen, Testlisten
docker/Dockerfile         Entwicklungsumgebung
docker-compose.yml        Container + Volumes
.devcontainer/            Für VS Code „Reopen in Container“
.claude/settings.json     Freigaben/Sperren für Claude Code (z. B. kein Zugriff auf .secrets/ und die echte App)
scripts/                  Hilfsskripte (siehe Kopfzeilen der Dateien)
.secrets/                 Signaturschlüssel (nicht in git, separat sichern)
```
