# Changelog

Alle Änderungen an GymLog, neueste Version oben. Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionsnummern nach [Semantic Versioning](https://semver.org/lang/de/).

Ablauf: Ist eine Version aus `docs/ROADMAP.md` umgesetzt, schreibt Claude Code hier einen Abschnitt `## [X.Y.Z] – unveröffentlicht` in Alltagssprache. `scripts/release.sh` ersetzt beim Veröffentlichen „unveröffentlicht“ durch das Datum, hängt die Liste der Commits an und übernimmt den Abschnitt als Text der GitHub-Release. Ein Eintrag pro Zeile, ohne Zeilenumbruch im Satz (GitHub zeigt jeden Umbruch an).

## [1.2.2] – unveröffentlicht

### Neu
- **Update-Hinweis beim Öffnen:** GymLog sucht jetzt bei jedem Öffnen nach einer neuen Version statt einmal am Tag. Ist eine da, zeigt es sie einmal mit ihren Neuerungen an und meldet sie per Benachrichtigung; während eines Trainings öffnet sich nichts von selbst.
- **Blauer Punkt** am Zahnrad und bei „Über“, solange ein Update bereitsteht.
- **Update-Seite:** „APK herunterladen“ lädt die neue Version im Browser – danach die Datei antippen und installieren, alle Trainings bleiben erhalten. „Auf GitHub ansehen“ öffnet die Release-Seite.
- **Neuerungen zum Aufklappen** unter Einstellungen → Über.

## [1.2.1] – 2026-11-09

### Neu
- **Trainingstage:** Für jeden Plan Wochentage mit Uhrzeit festlegen – direkt nach dem Anlegen oder später auf der Plan-Seite.
- **Aktive Pläne:** Pläne lassen sich auf inaktiv stellen; sie bleiben sichtbar, sind aber ausgegraut und erinnern nicht.
- **Erinnerung am Abend vorher** (Standard 20 Uhr) mit Knopf „Slot buchen“, der die Buchungsseite des Studios öffnet. Die Adresse steht in den Einstellungen.
- **Erinnerung vor dem Training** (Standard 1 Stunde) mit einem von über 30 Motivationssprüchen – mal frech, mal nerdig.
- **Pause auf dem Sperrbildschirm:** Countdown als Benachrichtigung, wenn GymLog im Hintergrund ist.
- **Training noch offen:** Hinweis, wenn 3 Stunden nach dem letzten Satz noch ein Training läuft.
- **Backup-Erinnerung** und **„Serie in Gefahr“** (Samstag 18 Uhr, wenn diese Woche noch kein Training war) als Benachrichtigung.
- **Update-Hinweis:** Einmal am Tag schaut GymLog nach, ob es auf GitHub eine neue Version gibt, und meldet sie; der Link öffnet die Download-Seite. Das ist der einzige Internetzugriff der App und lässt sich abschalten.
- Bereich **Einstellungen → Benachrichtigungen**: alles einzeln ein- und ausschaltbar, Uhrzeit und Vorlauf einstellbar.

### Hinweis
- Beim ersten Start fragt Android einmal, ob GymLog Benachrichtigungen senden darf.

### Geändert gegenüber der Vorabversion 1.2.0
- **Einstellungen neu geordnet:** eine Startseite mit Übungen, Pläne, Training, Benachrichtigungen, Automatische Buchung, Darstellung, Daten und Über – jeder Bereich auf einer eigenen Seite mit klar getrennten Abschnitten.
- **Plan-Seite:** Tippen auf einen Plan (oder langes Drücken auf seinen Chip im Training-Tab) öffnet alles an einem Ort: Name, „Aktiv“, Trainingstage, Duplizieren, Löschen.
- **„Frei“ entfällt:** Jedes Training startet aus einem Plan. Frühere freie Trainings bleiben im Verlauf.
- **„Nach Updates suchen“** unter Einstellungen → Über: sucht auf Antippen sofort und führt zur Release-Seite mit den Neuerungen.
- Die Buchungsseite steht jetzt unter „Automatische Buchung“.

<details>
<summary>Commits seit v1.1.0 (für Entwickler)</summary>

#### Features
- training days and notifications (1.2.0) (`e353422`)
- settings pages, plan page and no "Frei" (1.2.1) (`3306d13`)

</details>

## [1.1.0] – 2026-11-07

### Neu
- **Standard-Steigerung** in den Einstellungen unter Training, wahlweise in kg oder lbs (voreingestellt 15 lbs).
- **Geräte mit lbs-Scheiben:** + und − springen zur nächsten Scheibe, angezeigt und gespeichert wird der aufgedruckte kg-Wert (z. B. 45, 52, 59, 66 kg).
- **Gewichtsschritte je Übung:** „Standard“ (wie in den Einstellungen), „Eigene“ in kg oder lbs, oder „Stufen“ für Geräte mit nummerierten Stufen.
- **Stufen mit kg pro Stufe** zeigen z. B. „Stufe 10 (45 kg)“ und rechnen in kg; Stufen ohne kg-Angabe zeigen nur die Stufe.
- Der Steigerungsvorschlag nimmt die nächste Scheibe bzw. Stufe.

### Geändert
- Standardübungen an Geräten und Kabeln nutzen jetzt die Standard-Steigerung; Bizepscurls und Trizepsdrücken am Kabel nutzen Stufen à 4,5 kg. Bisherige Sätze bleiben unverändert.
- Stufen ohne kg-Angabe zählen nicht zum Wochenvolumen; der CSV-Export kennzeichnet sie in der neuen Spalte „weight_unit“.

<details>
<summary>Commits seit v1.0.1 (für Entwickler)</summary>

#### Features
- weight steps with lbs plates and levels (1.1.0) (`29fd218`)

#### Fehlerbehebungen
- show the kg/lbs switch right below the default step value (`34934d3`)

</details>

## [1.0.1] – 2026-11-07

Erste veröffentlichte Version: Krafttraining im Studio planen und mitschreiben, komplett offline und ohne Konto.

### Neu
- **Trainingspläne** mit Übungen, Ziel-Sätzen, Wiederholungen bzw. Dauer und eigener Pause; Reihenfolge per Ziehen.
- **94 Standardübungen** in acht Kategorien (Geräte, Kabel, Lang- und Kurzhantel, Eigengewicht, Zeitübungen wie Plank, Ausdauergeräte); eigene Übungen lassen sich jederzeit anlegen, bearbeiten und archivieren.
- **Training im Studio:** große Eingabefelder, Werte vom letzten Mal vorausgefüllt, Vorschlag zur Steigerung, jeder Satz wird sofort gespeichert. Display bleibt an, Stoppuhr für Zeitübungen.
- **Pausentimer** mit Vibration am Ende – auch wenn GymLog im Hintergrund ist oder das Display gesperrt ist.
- **Supersets** (abwechselnd, Pause erst nach der Runde) und **Rotationen** (Übungen wechseln sich von Training zu Training ab).
- **Rekorde** werden beim Speichern erkannt und hervorgehoben.
- **Verlauf** aller Trainings mit Details; Zeiten, Sätze und Notizen nachträglich änderbar, gelöschte Trainings lassen sich mit „Rückgängig“ zurückholen.
- **Statistik:** Kraftindex, deine Serie (Wochen in Folge mit Training) inklusive längster Serie, Körpergewicht, Wochenvolumen, Trainingskalender, Verlauf je Übung (geschätztes 1RM, Volumen, Bestwerte), Rekordliste – mit kurzen Erklärungen.
- **Körpergewicht** mit Verlauf und 7-Tage-Durchschnitt.
- **Daten:** Backup erstellen und wiederherstellen (auch auf einem neuen Handy), CSV-Export für Excel; an fällige Backups erinnern die Einstellungen.
- Hell- und Dunkelmodus, große Systemschrift wird unterstützt.

### Geändert nach dem Test der Vorabversion 1.0.0
- Keine Bestätigungsmeldungen mehr wie „Satz gespeichert“ oder „Training verworfen“; nur noch beim Löschen gibt es einen Hinweis mit „Rückgängig“, und er verschwindet nach 5 Sekunden von selbst.
- Supersets und Rotationen lassen sich im Plan zuverlässig zwischen zwei Übungen schieben: Beim Anfassen schrumpfen sie auf eine Zeile.
- Pause im Superset: kürzere Texte („Pause wie bei letzter Übung“, Menüpunkt „Pause einstellen“), der Dialog ändert seine Größe nicht mehr.
- Rotation: kompakter Dialog „Übung wechseln nach“.
- Statistik: Serie direkt nach dem Kraftindex, Körpergewicht ohne Schalter immer sichtbar.
- Backup-Erinnerung standardmäßig nach 30 Tagen und nur noch in den Einstellungen unter „Daten“, nicht mehr nach jedem Training.

### Behoben
- Nach „Beenden“ lief die letzte Pause weiter und vibrierte auf der Zusammenfassung.
- Beim Anlegen eines Plans erschien hinter der Tastatur ein gelb-schwarzer Streifen.

<details>
<summary>Alle Commits (für Entwickler)</summary>

#### Features
- scaffold app shell, theme and build configuration (M0) (`7368551`)
- add database, repositories and demo data (M1) (`2b7539f`)
- add exercise and plan management and the training tab (M2) (`f07ac4b`)
- add the session screen, finish flow and summary (M3) (`4cd9ee5`)
- add rest timer, keep-awake, suggestions, records and notes (M4) (`4daa96a`)
- add the history tab with session details (M5) (`bd760d4`)
- add the body weight tab (M6) (`d7e6a6f`)
- add the statistics tab (M7) (`76cecf0`)
- add export, backup, import and the remaining settings (M8) (`2f03b8a`)
- add supersets, rotations and explanations (M9) (`cd09292`)
- polish for version 1.0.0 (M10) (`31eb847`)
- ship a built-in exercise library with version 1.0.0 (`01d38fb`)

#### Fehlerbehebungen
- phone test findings as version 1.0.1 (`e3e2e10`)
- phone connect scripts refuse to run outside the container (`a9f56dc`)
- explain failed wireless pairing in phone-connect-wifi.sh (`4f70139`)
- keep only the target platform ABIs in the shared release APK (`f58ed8b`)

#### Dokumentation
- rename IMPROVEMENTS.md to ROADMAP.md (`fe96780`)
- rewrite README as a short guide, rename scripts (`8e67181`)

#### Build
- publish versions as GitHub releases with a changelog (`0600152`)
- run releases from the host, keep GitHub access out of the container (`05652f9`)
- release with the SSH key only, create the release in the browser (`79dbec4`)

#### Wartung
- add USB debugging setup for the dev container (`16a9cb8`)

#### Sonstiges
- Initial files (`f924622`)

</details>
