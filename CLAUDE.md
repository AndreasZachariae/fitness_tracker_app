# GymLog – Anweisungen für Claude Code

GymLog ist eine private, rein lokale Android-App (Flutter) zum Tracken von Krafttraining im Studio:
Trainingspläne, Sätze mit Gewicht/Wiederholungen/Dauer, Session-Timer, Statistiken, Körpergewicht, Export.
Es gibt genau einen Nutzer. Die App läuft offline, ohne Konto und ohne Server.

- **Verbindliche Spezifikation:** `docs/SPEC.md` – lies sie vollständig, bevor du anfängst.
- **Fortschritt, Annahmen, Testlisten:** `docs/PROGRESS.md` – halte sie aktuell.
- **Anleitung für den Menschen:** `README.md` (nicht für dich gedacht, nicht überschreiben).

## Umgebung

Du läufst in einem Docker-Dev-Container (Debian, User `flutter`, Projekt unter `/workspace`).
Installiert: Flutter 3.47.9 (stable) unter `/home/flutter/sdks/flutter`, Android SDK (Platform 36, Build-Tools 36, NDK) unter
`$ANDROID_HOME`, JDK 17, `adb`, `sqlite3`. Es gibt **keinen Emulator**. Ein echtes Handy ist eventuell per WLAN-adb verbunden
(`adb devices`). Internetzugang für pub.dev, Maven und GitHub ist vorhanden.

Halte dich an die Projektvorlage, die `flutter create` mit dieser Flutter-Version erzeugt. Nimm Framework- und Paket-APIs nicht
aus dem Gedächtnis an: Bei Unsicherheit im lokalen SDK (`/home/flutter/sdks/flutter`) oder im Pub-Cache (`$PUB_CACHE`) nachsehen.

## Befehle

| Zweck | Befehl |
|---|---|
| Format + Analyse + Tests (muss grün sein) | `./scripts/check.sh` |
| Code-Generierung (drift) | `dart run build_runner build --delete-conflicting-outputs` |
| Debug-APK bauen | `flutter build apk --debug` |
| DEV-App aufs Handy + starten | `./scripts/install-dev.sh` |
| Screenshot vom Handy | `./scripts/screenshot.sh <name>` → gibt Pfad zur PNG aus, die du dir ansehen kannst |
| Vorschau Release-Text (nur lesen) | `./scripts/release-notes.sh notes <version>`, Prüfung: `./scripts/release-notes.sh check <version>` |

`flutter run` ist interaktiv und blockiert – das startet nur der Mensch.

## Arbeitsweise

1. Arbeite die Meilensteine aus `docs/SPEC.md` §11 **der Reihe nach** ab. Ziehe nichts aus späteren Meilensteinen vor.
2. Vor jedem Meilenstein: kurzer Plan als Unterpunkte in `docs/PROGRESS.md`.
3. Nach jedem Meilenstein:
   - `./scripts/check.sh` grün, `flutter build apk --debug` erfolgreich,
   - wenn ein Gerät verbunden ist: `./scripts/install-dev.sh`, Screenshots der neuen Screens prüfen,
   - `docs/PROGRESS.md` aktualisieren (Häkchen, Annahmen, neue Abhängigkeiten, **manuelle Testliste fürs Handy**),
   - Commit (Conventional Commits, Englisch),
   - **Stopp:** dem Menschen berichten, was fertig ist und was er am Handy testen soll. Auf „weiter“ warten.
4. **Ab Version 1.0 (Roadmap):** Neue Funktionen stehen in `docs/ROADMAP.md` unter Versionsnummern. Eine Version nur
   umsetzen, wenn der Mensch es ausdrücklich sagt („Setze jetzt Version X um“). Ablauf wie bei einem Meilenstein (Plan,
   Tests, Testliste in `docs/PROGRESS.md`, Commit, Stopp), zusätzlich:
   - `version` in `pubspec.yaml` auf `X.Y.Z+N` setzen (Build-Nummer N immer + 1),
   - in `CHANGELOG.md` oben einen Abschnitt `## [X.Y.Z] – unveröffentlicht` auf Deutsch für Nutzer schreiben
     (Neu / Geändert / Behoben, ein Eintrag pro Zeile ohne Zeilenumbruch), `./scripts/release-notes.sh check X.Y.Z` grün,
   - Status der Version in `docs/ROADMAP.md` auf `FINISHED` setzen.
   Veröffentlichen (`scripts/release.sh`, auf dem PC) macht nur der Mensch.
5. Unklarheiten in der Spezifikation: Triff die Annahme, die Daten sicherer und die Bedienung einfacher macht, und dokumentiere
   sie unter „Annahmen“ in `docs/PROGRESS.md`. Nur bei grundlegenden Zielkonflikten nachfragen.

## Harte Regeln (Datensicherheit – keine Ausnahmen)

Auf dem Handy liegen echte Trainingsdaten in der Release-App `de.gymlog.app`. Deinstallation oder Signaturwechsel löscht sie.

1. **Niemals** `applicationId`/`namespace` (`de.gymlog.app`), den Debug-Suffix `.dev`, die Signatur-Konfiguration oder den
   Keystore ändern, neu erzeugen oder entfernen.
2. **Niemals** `adb uninstall`, `adb shell pm …`, `adb install …`, `flutter install`, `scripts/install-release.sh`,
   `scripts/build-release-apk.sh`, `scripts/release-build.sh`, `scripts/release.sh` oder `flutter build apk --release`
   ausführen (Release-Builds nutzen `.secrets/`). Kein `git push`, kein `git tag`, keine `gh`-Befehle. Releases startet nur
   der Mensch auf seinem PC; im Container gibt es absichtlich keinen GitHub-Zugang.
   Interaktion mit dem Handy ausschließlich über `scripts/install-dev.sh` und `scripts/screenshot.sh` (nur Paket `de.gymlog.app.dev`).
3. `.secrets/` weder lesen noch schreiben.
4. Datenbankschema nur per Migration ändern: `schemaVersion` + 1, Schema-Dump (`drift_dev schema dump`), Migrationstest.
   Keine destruktiven Migrationen, kein Drop/Recreate von Tabellen mit Nutzerdaten.
5. Jeder erfasste Satz wird **sofort** in der Datenbank gespeichert, nie erst beim Beenden der Session.
6. Keine `INTERNET`-Permission im Haupt-Manifest, keine Analytics, keine Crash-Reporter, keine Laufzeit-Downloads
   (Schriften als Assets bündeln). Erlaubte Permission: `VIBRATE`.

## Konventionen

- Code, Bezeichner, Kommentare und Commit-Messages auf Englisch. **UI-Texte auf Deutsch**, zentral in
  `lib/core/l10n/strings_de.dart`. Zahlen/Datum über `intl` mit Locale `de_DE` (Anzeige „62,5 kg“), Eingaben akzeptieren Komma und Punkt.
- Architektur und Ordnerstruktur wie in `docs/SPEC.md` §4. Domain-Logik (Formeln, Vorbefüllung, Rekorde, Kraftindex, CSV/JSON)
  als reines Dart ohne Flutter-Imports, vollständig unit-getestet.
- UI greift nie direkt auf die Datenbank zu, sondern über Repositories/Provider (Riverpod, ohne Codegen).
- Zeit nur über den injizierbaren Clock-Provider, damit Tests deterministisch sind. Zeitpunkte in UTC speichern, lokal anzeigen.
- Pakete: jeweils aktuelle stabile Version per `flutter pub add`. Vor Aufnahme pub.dev prüfen (Wartung, Android-Support).
  Neue Abhängigkeiten außerhalb von `docs/SPEC.md` §2 in `docs/PROGRESS.md` begründen.
- `flutter analyze` mit 0 Hinweisen; keine `print`-Aufrufe im App-Code.
- Generierte Dateien (`*.g.dart`) werden eingecheckt.
