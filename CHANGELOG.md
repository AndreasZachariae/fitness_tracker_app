# Changelog

Alle Änderungen an GymLog, neueste Version oben. Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionsnummern nach [Semantic Versioning](https://semver.org/lang/de/).

Ablauf: Ist eine Version aus `docs/ROADMAP.md` umgesetzt, schreibt Claude Code hier einen Abschnitt `## [X.Y.Z] – unveröffentlicht` in Alltagssprache. `scripts/release.sh` ersetzt beim Veröffentlichen „unveröffentlicht“ durch das Datum, hängt die Liste der Commits an und übernimmt den Abschnitt als Text der GitHub-Release. Ein Eintrag pro Zeile, ohne Zeilenumbruch im Satz (GitHub zeigt jeden Umbruch an).

## [1.0.1] – unveröffentlicht

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
