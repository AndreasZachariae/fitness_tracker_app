# Changelog

Alle Änderungen an GymLog, neueste Version oben. Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionsnummern nach [Semantic Versioning](https://semver.org/lang/de/).

Ablauf: Ist eine Version aus `docs/ROADMAP.md` umgesetzt, schreibt Claude Code hier einen Abschnitt `## [X.Y.Z] – unveröffentlicht` in Alltagssprache. `scripts/release.sh` ersetzt beim Veröffentlichen „unveröffentlicht“ durch das Datum, hängt die Liste der Commits an und übernimmt den Abschnitt als Text der GitHub-Release. Ein Eintrag pro Zeile, ohne Zeilenumbruch im Satz (GitHub zeigt jeden Umbruch an).

## [1.0.0] – unveröffentlicht

Erste veröffentlichte Version: Krafttraining im Studio planen und mitschreiben, komplett offline und ohne Konto.

### Neu
- **Trainingspläne** mit Übungen, Ziel-Sätzen, Wiederholungen bzw. Dauer und eigener Pause; Reihenfolge per Ziehen.
- **94 Standardübungen** in acht Kategorien (Geräte, Kabel, Lang- und Kurzhantel, Eigengewicht, Zeitübungen wie Plank, Ausdauergeräte); eigene Übungen lassen sich jederzeit anlegen, bearbeiten und archivieren.
- **Training im Studio:** große Eingabefelder, Werte vom letzten Mal vorausgefüllt, Vorschlag zur Steigerung, jeder Satz wird sofort gespeichert. Pausentimer mit Vibration, Stoppuhr für Zeitübungen, Display bleibt an.
- **Supersets** (abwechselnd, Pause erst nach der Runde) und **Rotationen** (Übungen wechseln sich von Training zu Training ab).
- **Rekorde** werden beim Speichern erkannt und hervorgehoben.
- **Verlauf** aller Trainings mit Details; Zeiten, Sätze und Notizen nachträglich änderbar.
- **Statistik:** Verlauf je Übung (geschätztes 1RM, Volumen, Bestwerte), Kraftindex, Wochenvolumen, Trainingskalender, Rekordliste – mit kurzen Erklärungen.
- **Körpergewicht** mit Verlauf und 7-Tage-Durchschnitt.
- **Daten:** Backup erstellen und wiederherstellen (auch auf einem neuen Handy), CSV-Export für Excel, Erinnerung an Backups.
- Hell- und Dunkelmodus, große Systemschrift wird unterstützt.
