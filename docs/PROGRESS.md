# Fortschritt

Wird von Claude Code gepflegt. Vor jedem Meilenstein den Plan als Unterpunkte eintragen, danach abhaken.

## Meilensteine

- [x] M0 Grundgerüst (0.1.0+1)
  - [x] `flutter create --project-name gymlog --org de.gymlog --platforms android .`, vorhandene Dateien unverändert lassen, `.gitignore` ergänzen
  - [x] Android: `namespace`/`applicationId` `de.gymlog.app`, Debug-Suffix `.dev`, App-Namen per `resValue`, Release-Signatur aus `../.secrets/key.properties` mit Abbruch ohne Datei
  - [x] Manifest: nur `VIBRATE`, Hochformat, `allowBackup` Standard; `INTERNET` nur in debug/profile-Manifest (Flutter-Tooling)
  - [x] Lints (`flutter_lints` + strengere Regeln, `avoid_print`), Pakete aus §2
  - [x] Ordnerstruktur §4, `strings_de.dart`, Clock-Provider, Formatierung de_DE (Grundlage)
  - [x] Theme hell/dunkel von Hand (§9), Barlow + Barlow Semi Condensed als Assets inkl. OFL-Lizenz
  - [x] Shell mit vier Tabs (`StatefulShellRoute`), Zahnrad → Einstellungen-Route über der Shell
  - [x] Tests (Clock, Formatierung, Kontraste, Widget-Test Navigation), `check.sh` grün, Debug-APK
- [x] M1 Datenbank (0.2.0+2)
  - [x] Domain-Modelle (reines Dart): Enums mit Spec-Codes (`weight_reps`, `full_body` …), `LocalDate`, Modelle aller Tabellen, Satz-Validierung
  - [x] drift-Tabellen §5 mit `@UseRowClass` auf die Domain-Modelle, FKs (cascade/restrict/set null), CHECKs, Unique-Keys, Indizes,
        Teil-Index „höchstens eine aktive Session“, DateTime als UTC-ISO-Text, `foreign_keys`, WAL + `synchronous=FULL`
  - [x] Settings-Zeile `id = 1` bei Erstellung + Absicherung beim Öffnen
  - [x] DAOs + Repositories (Exercise, Plan, Session, BodyWeight, Settings) mit Streams, Clock, eigene Exceptions
  - [x] Schema-Dump-Setup (`build.yaml`, `drift_schemas/`, `make-migrations`, Schema-Test für v1)
  - [x] Repository-/Schema-Tests: eine aktive Session, Archivieren statt Löschen, Kaskaden, Restrict, Set-null, CHECKs
  - [x] Demo-Daten-Generator (rein, deterministisch) + `replaceAll`/`wipeAll` in einer Transaktion
  - [x] Einstellungen (nur Dev-Build): „Demo-Daten erzeugen“, „Alle Daten löschen“ mit Bestätigung; Theme folgt `themeMode`
- [x] M2 Übungen und Pläne (0.3.0+3)
  - [x] Repository-Ergänzungen: letzte Leistung je Übung („Zuletzt: …“), zuletzt verwendete Übungen, Anzahl Übungen je Plan,
        Plan-Eintrag wiederherstellen (Rückgängig), Typwechsel bei Übungen mit Historie sperren
  - [x] Formatierung: Ziel („3 × 10“, „3 × 45 s“, „3 Sätze“), Satz-Zusammenfassung („60 kg × 10, 10, 8“), Kategorie-/Typ-Namen
  - [x] Geteilte Widgets: Stepper, Namensdialog, gestrichelter „+ Übung hinzufügen“-Button, Fehlermeldungen auf Deutsch
  - [x] Einstellungen → Übungen: Suche, Kategorie-Filter, anlegen, bearbeiten, archivieren/löschen, Archiv mit „Wiederherstellen“
  - [x] Einstellungen → Pläne: Reorder, anlegen, umbenennen, duplizieren, löschen
  - [x] Training-Tab §6.1: Plan-Chips (+ Plan, Long-Press-Menü, Auswahl gemerkt), Liste mit Reorder/Wischen+Rückgängig/
        „Im Plan bearbeiten“, Übung-hinzufügen-Sheet (Suche, Zuletzt verwendet, nach Kategorie, Neue Übung), Modus „Frei“,
        „Training starten“
  - [x] Bis M3: schlichte Platzhalter-Ansicht für die laufende Session (nur Übersicht + „Beenden“ → verwerfen)
  - [x] Widget- und Repository-Tests
- [x] M3 Session-Kern (0.4.0+4)
  - [x] Domain (rein, Tabellentests): Vorbefüllung §7.1, Reorder-Regeln (erledigte fest), nächste offene Übung, vergessene
        Session (12 h, Ende = letzter Satz + 5 min), Volumen §7.6, bester Satz, „Plan geändert?“
  - [x] SessionRepository: Satz speichern mit Statuswechsel (+ `autoActivateNext`) und Rückgängig, aktivieren, überspringen,
        Übung beenden, wieder öffnen, +1 Satz, Satz ändern/löschen, Übung zur Session, Reorder, Beenden nach §6.3, Notiz,
        Vergleich mit letzter Session desselben Plans
  - [x] PlanRepository: Reihenfolge/neue Übungen aus Session übernehmen, Session als Plan speichern
  - [x] Session-Ansicht §6.2: AppBar mit Timer + „Beenden“, Kacheln offen/aktiv/erledigt/übersprungen, große Stepper je Typ,
        Zahlentastatur per Tap, Stoppuhr, „Letztes Mal (…)“, Satzliste mit Ändern/Löschen, Snackbar „Satz gespeichert“ +
        Rückgängig, Haptik, nächste offene Kachel markiert, Reorder nur offen/aktiv, „+ Übung hinzufügen“
  - [x] Beenden §6.3 (Dialoge) + Zusammenfassung (Dauer, Übungen, Sätze, Volumen, ±% zum letzten Mal, Plan übernehmen /
        als Plan speichern, Notiz, „Fertig“)
  - [x] Leiste „Training läuft – 42:13“ + Punkt am Training-Icon auf anderen Tabs; Wiederaufnahme; Dialog vergessene Session
  - [x] Widget-Tests: Session-Ablauf, Reorder-Regeln, Rückgängig, Beenden-Dialoge, vergessene Session
- [x] M4 Komfort im Studio (0.5.0+5)
  - [x] Domain: e1RM (§7.3), Rekordarten + Rekord-Erkennung chronologisch inkl. „erste Session“ (§7.7), Steigerungsvorschlag
        (§7.2), Pausendauer/-zustand (§6.2.1)
  - [x] Geräte-Dienste injizierbar (Vibration, Haptik, Display an) mit Fakes für Tests
  - [x] Repository: Rekorde beim Speichern, Rekord-Sätze einer Session als Stream, neue Rekorde für die Zusammenfassung
  - [x] Pausentimer-Leiste über der Tableiste (−15 s/+15 s/Überspringen, Fortschritt, Vibration, „Pause vorbei“ 10 s)
  - [x] Display bleibt an während der Session (`keepScreenOn`)
  - [x] Vorschlags-Chip in Satz 1, Rekord: rotes Aufleuchten + Label + mittlere Haptik, Rekorde in der Zusammenfassung
  - [x] Übungsnotiz in der aktiven Kachel (Tap → bearbeiten)
  - [x] Tests (Tabellen für Domain, Repository, Widgets)
- [x] M5 Verlauf (0.6.0+6)
  - [x] Repository: Verlaufsliste als Stream (Dauer, Sätze, Volumen, Rekord-Markierung), Session beobachten, Zeiten ändern
        (validiert), Übung aus Session entfernen
  - [x] Domain: Prüfung Start/Ende, Monatsgruppen
  - [x] Verlauf-Tab: nach Monat gruppiert, Einträge „Di, 3.11.“, Plan/Freies Training, Dauer, Sätze, Volumen, Rekord
  - [x] Detail: Datum, Start–Ende ändern, Notiz, Sätze je Übung (ändern/löschen, Rekord-Label), Übung entfernen, Session
        löschen mit Bestätigung (Datum + Planname)
  - [x] Tests
- [x] M6 Körper (0.7.0+7)
  - [x] Domain: Zeiträume 4 W/3 M/1 J/Alles, gleitender 7-Tage-Durchschnitt (§7.8), Kennzahlen (aktuell Ø 7 Tage,
        Veränderung 30 Tage, Min/Max im Zeitraum)
  - [x] Eingabekarte: kg (eine Nachkommastelle, letzter Wert vorbefüllt), Datum-Chip „Heute“ (keine Zukunft), Speichern,
        Überschreiben-Rückfrage
  - [x] Diagramm (Messpunkte + Ø-7-Linie) mit Zeitraum-Auswahl, Kennzahlen
  - [x] Liste neueste zuerst, Wischen → löschen mit „Rückgängig“, Tippen → bearbeiten
  - [x] Tests
- [x] M7 Statistik (0.8.0+8)
  - [x] Domain `calendar.dart`: ISO-Wochen (Jahreswechsel), Wochenanfang
  - [x] Domain `statistics.dart`: effektive Last (§7.3), Leistungswert P (§7.4), Kraftindex mit Fortschreiben ≤ 8 Wochen
        (§7.5), Wochenvolumen (§7.6), Metriken je Übungstyp, Rekordpunkte, Heatmap 26 Wochen, Ø Trainings/Woche, Serie,
        Trainingsdauer, Sätze pro Kategorie, Rekord-Übersicht – alles Tabellentests
  - [x] Repository: alle beendeten Trainings + Körpergewicht als ein Stream
  - [x] Statistik-Tab: Zeitraum, Tabs Übung (Auswahl mit Suche, Metrik-Chips, Liniendiagramm mit Tooltip und Rekordpunkten,
        Kennzahlen, letzte 10 Trainings) · Gesamt (Kraftindex + 100-%-Linie, Körpergewicht einblendbar, Wochenvolumen,
        Kalender-Heatmap mit Ø/Woche und Serie, Dauer, Sätze pro Kategorie) · Rekorde (Tippen → Übung)
  - [x] Leerzustände je Diagramm; Performance-Messung mit 1 Jahr Demo-Daten (`compute`, falls > ~50 ms)
- [x] M8 Daten und Einstellungen (0.9.0+9)
  - [x] Domain `serialization/`: CSV nach RFC 4180 (4 Dateien, Spalten §8.1), JSON-Backup (§8.2) mit Validierung
        (Format, Version, Pflichtfelder, Typen, referentielle Integrität) und Vorschau
  - [x] Export/Import-Dienst: ZIP, Backup, Sicherheitskopie vor Import (letzte 3), Import in einer Transaktion, gesperrt
        während einer Session; Teilen/„Speichern unter …“/Datei wählen hinter injizierbarer Schnittstelle
  - [x] Pflicht-Test Export → Import → identischer Datenbankinhalt
  - [x] Einstellungen §6.7: Training, Darstellung, Daten (CSV, Backup erstellen/wiederherstellen, letztes Backup,
        Erinnerung), Über (Version, Build, Schemaversion)
  - [x] Backup-Hinweis in der Zusammenfassung (§6.3)
  - [x] Tests
- [x] M9 Verbesserungen aus `docs/ROADMAP.md` (Version 0.10.0) (0.10.0+10, zusätzlicher Meilenstein auf Wunsch, vor 1.0)
  - [x] Info-Symbole in der Statistik (Metriken, Kraftindex, Wochenvolumen, Kalender, Rekorde) und am Schalter
        „Im Kraftindex“ im Übungsformular (Erklärung inkl. rückwirkender Neuberechnung)
  - [x] Plan-Chips ohne Haken, farbig hervorgehoben, sofortige Auswahl ohne Ruckeln
  - [x] Statistik „Veränderung“: Prozentwert immer in eigener Zeile
  - [x] Schema 2 (Migration 1 → 2, additiv): `plan_groups` (Superset/Rotation mit Pause, Wechselrhythmus,
        aktueller Übung, Zähler), `plan_exercises.group_id`, `session_supersets`, `session_exercises.superset_id`;
        Backup-Format 2 (liest weiterhin Format 1)
  - [x] Domain: Blöcke (einzeln/Gruppe), Superset-Ablauf abwechselnd mit Pause nach jeder Runde, Rotation
        (Weiterrücken nur, wenn die aktive Übung trainiert wurde), Plan übernehmen/als Plan speichern mit Gruppen
  - [x] Training-Tab: „Superset erstellen“ (orange) und „Rotation erstellen“ (grün, nur Pläne) unter „+ Übung
        hinzufügen“; Gruppen als Rahmen, als Ganzes verschiebbar, innen umsortierbar; Menü (Pause, Wechsel, Übung
        hinzufügen, auflösen)
  - [x] Laufende Session: Supersets anzeigen, befolgen und neu bilden; Pausentimer erst nach der Runde
  - [x] Demo-Daten mit Superset und Rotation, Tests (Domain, Migration, Repository, Widgets), Testliste
  - [x] Zusätzlich: Test, dass jedes Zeichen der UI-Texte in den gebündelten Schriften existiert („→“ fehlte)
- [x] M10 Feinschliff, Version 1.0.0 (SPEC §11 „M9“; nach dem eingeschobenen M9 jetzt M10) (1.0.0+11)
  - [x] Leerzustände aller Screens geprüft; neu: leere Session und Verlaufsdetail ohne Übungen (Test mit leerer Datenbank)
  - [x] Hell/Dunkel: Startbild und Statusleiste passend zum Theme (kein weißer Blitz, dunkle Symbole im hellen Modus),
        Android-12-Splash mit farbigem Icon-Kreis
  - [x] Schriftskalierung: alle Screens mit Demo-Daten bei 1,3/1,5/2,0 ohne Überlauf (automatischer Test mit den echten
        Schriften); behoben: Snackbar, Verlaufsdetail „übersprungen“, Sätze pro Kategorie, Statistik-Tabs
  - [x] Launcher-Icons: Hantel, adaptiv + themed (Android 13) + Legacy; Release blau/weiß, DEV gelb mit „DEV“
        (debug/profile-Ressourcen), Generator `tool/icons/generate_launcher_icons_test.dart`
  - [x] Performance-Check mit 1 Jahr Demo-Daten (`test/data/performance_test.dart`, Messwerte unter „Annahmen“)
  - [x] Gesamt-Testliste fürs Handy, Version 1.0.0+11
  - [x] Nachtrag aus `docs/ROADMAP.md` (1.0.0+12): mitgelieferte Übungsbibliothek mit 94 Übungen (Geräte, Kabel,
        Lang-/Kurzhantel, Eigengewicht, Zeitübungen, Ausdauergeräte) in allen acht Kategorien; neue Datenbank startet
        damit, Einstellungen → Übungen → „Standardübungen hinzufügen“ ergänzt fehlende; Tests
  - [x] Gesamt-Testliste am Handy abgearbeitet (Mensch, 2026-11-06); Anmerkungen → Version 1.0.1
- [x] 1.0.1 Bugfixes nach dem Handytest (`docs/ROADMAP.md`, 1.0.1+13), erste veröffentlichte Version
  - [x] Snackbars: keine Bestätigungen mehr; nur Fehler, Hinweise und Löschen mit „Rückgängig“ (Körpergewicht, Training
        im Verlauf – neu mit Wiederherstellung –, Übung aus Plan/freier Liste); verschwinden nach 5 s von selbst
  - [x] „+ Plan“: Trainingsseite schrumpft nicht mehr hinter der Tastatur (gelb-schwarzer Überlaufstreifen)
  - [x] Supersets/Rotationen beim Ziehen am Griff auf eine Zeile verkleinert → landen zuverlässig zwischen zwei Übungen
        (Plan, freie Liste und Session)
  - [x] Superset-Texte kürzer („Pause wie bei letzter Übung“, Menü „Pause einstellen“), Pausendialog mit fester Größe;
        Rotationsdialog kompakt („[−] 2 [+] Trainings“), Menü „Wechsel einstellen“
  - [x] Pausen-Vibration im Hintergrund/bei gesperrtem Display über exakten Android-Alarm (neue Permissions, vom Menschen
        freigegeben); nach „Beenden“/„Verwerfen“ endet die Pause
  - [x] Backup-Hinweis aus der Zusammenfassung in Einstellungen → Daten verschoben; Erinnerung standardmäßig 30 Tage
  - [x] Statistik: Serie als eigene Karte direkt nach dem Kraftindex (mit längster Serie „nicht aktiv“), Körpergewicht
        ohne Schalter
  - [x] CHANGELOG 1.0.1 (enthält die nie veröffentlichte 1.0.0), Tests, Testliste
- [x] 1.1.0 Gewichtseinstellungen (`docs/ROADMAP.md`, 1.1.0+14)
  - [x] Schema 3 (Migration 2 → 3, additiv): `exercises.step_mode`, `increment_lbs`, `level_kg`;
        `app_settings.default_step`, `default_step_unit`; Datenschritt für Standardübungen an Geräten/Kabeln
  - [x] Domain `weight_steps.dart`: kg-Schritte, lbs-Scheiben (kg gerundet), Stufen mit/ohne kg pro Stufe
  - [x] Einstellungen → Training: Standard-Steigerung mit kg/lbs; Übungsformular: Standard / Eigene (kg/lbs) / Stufen
  - [x] Training: Stepper, Direkteingabe (Stufe), Vorschlag; Anzeige „Stufe 10 (45 kg)“ in Session, Verlauf, Statistik,
        Rekorden; Stufen ohne kg nicht im Volumen
  - [x] Umrechnen beim Wechsel zwischen „Stufen ohne kg“ und kg (mit Rückfrage), Backup-Format 3, CSV-Spalten
  - [x] Tests (Domain, Migration mit Daten, Repository, Widgets), CHANGELOG, Testliste
- [x] 1.2.0 Benachrichtigungen (`docs/ROADMAP.md`, 1.2.0+15)
  - [x] Schema 4 (additiv): `plans.active`, Tabelle `plan_schedules` (Wochentag + Uhrzeit), Einstellungen für
        Benachrichtigungen, Buchungslink, Update-Prüfung
  - [x] Pläne: Trainingstage mit Uhrzeit beim Anlegen und Bearbeiten, „aktiv“; inaktive Pläne ausgegraut
  - [x] Erinnerungen (flutter_local_notifications, offline): Abend vorher mit „Slot buchen“, 1 h vorher mit
        Motivationsspruch, Training noch offen (3 h), Backup fällig, Serie in Gefahr (Sa 18 Uhr); nach Neustart neu geplant
  - [x] Pause als Countdown-Benachrichtigung auf dem Sperrbildschirm
  - [x] Update-Hinweis: höchstens einmal am Tag GitHub-Releases abfragen (einziger Internetzugriff), Link im Browser
  - [x] Einstellungen → Benachrichtigungen; Backup-Format 4; Demo-Pläne mit Trainingstagen; Tests; CHANGELOG; Testliste
- [x] 1.2.1 Verbesserungen an 1.2.0 (`docs/ROADMAP.md`, 1.2.1+16), gemeinsames Release mit 1.2.0
  - [x] Einstellungen: Startseite mit Unterseiten (Übungen, Pläne, Training, Benachrichtigungen, Automatische Buchung,
        Darstellung, Daten, Über), Abschnitte mit Linie und farbiger Überschrift; Stepper-Beschriftung wie Listeneinträge
  - [x] Buchungsseite unter „Automatische Buchung“; Untertitel der Update-Suche ohne „einziger Internetzugriff“
  - [x] Plan-Seite (Name, Aktiv, Trainingstage, Duplizieren, Löschen) statt Drei-Punkte-Menü und Blatt; öffnet sich aus
        Einstellungen → Pläne, per langem Druck auf einen Chip und nach dem Anlegen
  - [x] „Frei“ abgeschafft: immer ein Plan gewählt (sonst der erste), ohne Pläne Hinweis mit „Plan anlegen“
  - [x] Über → „Nach Updates suchen“ auf Antippen, mit „Zur Release-Seite“; Tests; CHANGELOG [1.2.1]
- [x] 1.2.2 DEV-App und Updates über GitHub (`docs/ROADMAP.md`, 1.2.2+17)
  - [x] Build-Typ `beta`: DEV-App (`.dev`, Debug-Schlüssel) im Release-Modus; Version `X.Y.Z-dev.N`, Build `100000 + N`
        (N = Anzahl Commits), auch für `install-dev.sh`
  - [x] Skripte: `dev-version.sh`, `build-dev-apk.sh` (Container), `release-dev.sh` (PC: Token, Push per SSH, eine
        Vorab-Release „dev“ ersetzen, APK hochladen), `release-notes.sh dev` (Testliste + Änderungen + Commits)
  - [x] App: Suche bei jedem Start und Zurückkehren, echte App → neueste Release, DEV → Vorab-Release „dev“
  - [x] Update-Seite: Neuerungen/Testliste, „APK herunterladen“ (Browser), „Auf GitHub ansehen“; öffnet sich einmal pro
        Version (nicht im Training), auch aus der Benachrichtigung und aus Über
  - [x] Über: „Neuerungen der neuesten Version“ bzw. „Testliste und Änderungen (DEV)“ zum Aufklappen
  - [x] CLAUDE.md-Regeln, Deny-Liste, README, Tests
  - [x] Nach dem ersten Handy-Test: Play Protect blockierte die DEV-App als schädlich → Selbst-Installieren samt
        `REQUEST_INSTALL_PACKAGES`, Download und FileProvider ausgebaut, der Browser lädt die APK
  - [x] Nach dem ersten Handy-Test: Update beim Öffnen nicht gefunden (15-Minuten-Sperre) → bei jedem Start sofort, beim
        Zurückkehren höchstens jede Minute, Anfragen mit ETag; blauer Punkt an Zahnrad und „Über“
  - [x] Auf Wunsch: `release.sh` legt die Release mit Text und APK selbst an (gleicher Token, gemeinsamer Teil
        `scripts/lib/github.sh`); der Browser nur noch als Notweg

## Annahmen
- **1.2.2 Versionsnummer:** „DEV-App und Updates über GitHub“ als 1.2.2, damit die geplanten 1.3.0 (Automatische Buchung)
  und 1.4.0 ihre Nummern behalten.
- **1.2.2 DEV-Build für GitHub:** Eigener Build-Typ `beta` (Release-Modus, schnell wie die echte App, aber Paket
  `de.gymlog.app.dev`, gelbes Icon, Debug-Schlüssel des Containers, ohne R8-Verkleinerung, weil Flutter seine R8-Regeln
  nur für `release` einträgt). Der Release-Schlüssel aus `.secrets/` wird dafür nie benutzt. Debug- und Beta-Build haben
  denselben Schlüssel und dieselbe Nummerierung (`X.Y.Z-dev.N`, Build `100000 + N`), also gehen Kabel-Installation und
  Update über GitHub in beide Richtungen; 100000 liegt über allen alten DEV-Build-Nummern.
- **1.2.2 Vorab-Release:** Genau eine Release mit Tag `dev`, `prerelease`, nie „Latest“; `release-dev.sh` löscht die
  alte Release und den Tag und legt beide neu an (der Tag zeigt auf den gepushten Commit). `release.sh` und
  `release-dev.sh` holen nur `main` und `v*`-Tags, damit der wandernde Tag nicht stört. Der GitHub-Token
  (fine-grained, nur dieses Repository, Contents: Read and write) liegt auf dem PC unter `~/.config/gymlog/github-token`,
  außerhalb des Projektordners und damit außerhalb des Containers. Derselbe Token dient seit 1.2.2 auch `release.sh`
  (Wunsch des Menschen): Release erst als Entwurf anlegen, APK hochladen, dann veröffentlichen – so sieht weder ein
  Mensch noch die Update-Suche eine Release ohne APK; scheitert ein Schritt, wird der Entwurf gelöscht und `release.sh`
  öffnet wie früher die vorausgefüllte Seite im Browser.
- **1.2.2 Testliste in der DEV-Release:** Der erste `###`-Abschnitt unter „Manuelle Tests am Handy“ in dieser Datei, also
  die neueste Testliste; dazu der oberste Changelog-Abschnitt, solange er „unveröffentlicht“ ist.
- **1.2.2 Update-Suche:** Bei jedem Start der App immer, beim Zurückkehren höchstens einmal pro Minute (die erste
  Fassung mit 15 Minuten fand ein frisch veröffentlichtes DEV-Update beim Öffnen nicht). GitHub erlaubt ohne Konto
  60 Anfragen pro Stunde; deshalb fragt GymLog mit dem ETag der letzten Antwort, und „unverändert“ (304) zählt nicht.
  Abschaltbar wie bisher. Ein bekanntes Update zeigt sich als blauer Punkt am Zahnrad (jeder Tab) und bei „Über“. Die DEV-App vergleicht nur den Zähler N; Versionen ohne Zähler (z. B.
  `flutter run`) bekommen kein Update angeboten. Neu gefundene Version: einmal Benachrichtigung und einmal die
  Update-Seite – aber nicht während eines laufenden Trainings (dann nur Benachrichtigung und Hinweis in den
  Einstellungen). Release-Text und APK-Adresse bleiben nur im Speicher (keine Schemaänderung).
- **1.2.2 Kein Selbst-Installieren:** Die erste Fassung lud das Update selbst und installierte es
  (`REQUEST_INSTALL_PACKAGES`, FileProvider). Play Protect blockierte diese DEV-App beim Installieren aus dem Browser als
  schädlich – das Muster „lädt APKs aus dem Internet und installiert sie“ ist typisch für Dropper, zumal ohne Play Store
  und mit unbekanntem Schlüssel. Daher ausgebaut: „APK herunterladen“ öffnet die APK-Adresse im Browser, der Browser lädt
  sie, der Nutzer tippt die Datei an. Die App hat wieder genau die Rechte von 1.2.1 und nutzt das Internet nur für die
  Abfrage. Fehlt in der Release die APK, gibt es nur „Auf GitHub ansehen“.
- **1.2.2 Release-Text in der App:** Eigener kleiner Markdown-Leser (Domain, getestet) statt eines Pakets: Überschriften,
  Listen, Testlisten-Kästchen, fett, Code, Links als Text. Weggelassen werden die Commit-Liste (`<details>`) und alles
  nach `---` (Installationsanleitung der Release-Seite).

<!-- Entscheidungen, die die Spezifikation offenlässt: Was wurde angenommen, warum? -->

**M0**
- **Build-Typ `profile` ist ebenfalls eine DEV-App** (`.dev`, „GymLog DEV“, Debug-Signatur). Das Flutter-Gradle-Plugin legt
  `profile` per `initWith(debug)` an, *bevor* `build.gradle.kts` den Debug-Suffix setzt – ohne explizite Konfiguration hätte
  ein Profile-Build die ID der echten App `de.gymlog.app` bekommen.
- **Release-Signatur:** Eigene Task `verifyReleaseSigning` hängt vor `:app:preReleaseBuild` und bricht ohne
  `.secrets/key.properties` mit „Signaturschlüssel fehlt – siehe README, Schritt 4“ ab; kein Fallback auf den Debug-Key.
  Verdrahtung per `assembleRelease --dry-run` geprüft. Ein echter Release-Build wurde nicht ausgeführt (`.secrets/` tabu).
- **`INTERNET`** steht nur im Debug-/Profile-Manifest der Flutter-Vorlage (für Hot Reload/Debugger nötig). Das zusammengeführte
  Release-Manifest enthält nur `VIBRATE` und `de.gymlog.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (automatisch von
  AndroidX Core, interne Signatur-Permission, keine Nutzer-Berechtigung). Ein Test sichert das Haupt-Manifest ab.
- **Version:** `0.x` bis M9 (dann `1.0.0`), Build-Nummer +1 je Meilenstein. M0 = `0.1.0+1`.
- `cupertino_icons` aus der Vorlage entfernt (nur Android, ungenutzt).
- **Farben:** `ColorScheme` hell/dunkel von Hand. Im Dunkelmodus ist `primary` ein helleres Blau (`#82AEF0`) für Text/Icons;
  Hauptaktionen (`FilledButton`) sind in beiden Modi Scheibe Blau `#1F5FBF` mit Weiß. Zusätzliche Semantikfarben
  (Erledigt, Pause, Rekord, aktive Kante) als `ThemeExtension` `GymColors`. Alle Paare per Test auf WCAG-Kontrast geprüft.
- **Weiß auf Scheibe Grün** hat nur 4,25:1 → auf grünen Flächen nur große bzw. fette Schrift (≥ 3:1-Regel), z. B. „Pause vorbei“.
- **Schriften:** Barlow 400/500/600/700, Barlow Semi Condensed 500/600/700 (aus `google/fonts`, OFL). Beide haben `tnum`;
  ein Test misst, dass alle Ziffern gleich breit sind. Lizenz unter `assets/fonts/OFL.txt`, auch in der Lizenzseite registriert.
- `themeMode` ist bis zur Einstellungs-Zeile (M1) fest „System“.
- Zahleneingabe (`parseDecimal`) akzeptiert Komma und Punkt, aber keine Tausendertrennzeichen.
- Analyzer zusätzlich mit `strict-casts`, `strict-inference`, `strict-raw-types` und einigen strengeren Lints.
- Unterscheidbares DEV-Launcher-Icon: erledigt in M10 (gelb mit „DEV“).
- Beim App-Start zeigte das Startbild-Theme der Vorlage (`LaunchTheme`) kurz weiße Statusleisten-Symbole auf hellem
  Grund, bis Flutter übernimmt. Erledigt in M10.
- **USB-Debugging im Container:** `/dev/bus/usb` als Bind-Mount plus `device_cgroup_rules: c 189:* rmw` statt `devices:`,
  weil Android sich bei jedem Einstecken mit neuer Gerätenummer anmeldet. Zugriffsrechte über eine udev-Regel auf dem Host
  (`scripts/host-setup-usb.sh`, Gruppe = Host-GID = Container-GID).

**M1**
- **Domain-Modelle sind die drift-Zeilen** (`@UseRowClass`, reines Dart in `lib/domain/models`): kein doppeltes Modell,
  kein Mapping-Code. Enums werden mit den Codes aus §5 gespeichert (`weight_reps`, `full_body` …).
- **Zeitpunkte:** ISO-8601-Text in UTC mit genau Millisekunden (`2026-11-03T17:20:00.000Z`). drift schreibt sonst je nach
  Mikrosekunden unterschiedlich lange Texte, und SQL sortiert dann falsch. Alle Schreibwege gehen über `storageTime()`,
  die `SystemClock` liefert schon Millisekunden.
- **Haltbarkeit:** `foreign_keys = ON`, `journal_mode = WAL`, `synchronous = FULL`; jede Änderung in einer Transaktion.
- **Höchstens eine aktive Session:** Repository prüft (`ActiveSessionExistsException`), zusätzlich eindeutiger Teil-Index
  `sessions_single_active` als letzte Absicherung in SQLite.
- **Eindeutige Namen** (Übungen und Pläne): Leerraum wird bereinigt, max. 60 Zeichen, Vergleich ohne Groß-/Kleinschreibung
  **inkl. Umlaute** im Repository (`nameKey`). Der SQLite-Index `COLLATE NOCASE` faltet nur ASCII und ist nur Absicherung.
  Archivierte Übungen blockieren ihren Namen weiter (sonst Kollision beim Wiederherstellen).
- **Sortierung** von Übungsnamen nach DIN 5007-1 (ä = a, ß = ss), sonst stünde „Übung“ hinter „Zug“.
- **Übung löschen/archivieren** entfernt sie in beiden Fällen aus allen Plänen; mit Trainingshistorie wird archiviert,
  sonst gelöscht. „Wiederherstellen“ fügt sie nicht wieder in Pläne ein. (UI-Hinweis darauf folgt in M2.)
- **Ziel-Sätze:** im Plan 1–10 (§5); in der Session nur ≥ 1, weil „+1 Satz“ (M3) über 10 hinausgehen kann.
- **Sätze:** Gespeichert werden nur die Felder des Typs (`weight_reps`: Gewicht + Wdh; `bodyweight`: Zusatzgewicht,
  Standard 0, + Wdh; `timed`: Dauer + optionales Gewicht). Löschen eines Satzes nummeriert die folgenden neu (1..n).
  Neue Sätze nur in der laufenden Session; Bearbeiten im Verlauf kommt mit M5.
- **Körpergewicht:** 20–400 kg, auf eine Nachkommastelle gerundet, kein Datum in der Zukunft. Gleicher Tag überschreibt
  den Eintrag (gleiche id, `createdAt` bleibt).
- **Einstellungen:** Standard-Sätze 1–10, Pause 0–3600 s, Backup-Erinnerung 0–365 Tage. `lastSelectedPlanId` und
  `sessions.planId` werden beim Löschen des Plans per Fremdschlüssel auf `null` gesetzt. Das Theme folgt jetzt `themeMode`
  (Einstellung dafür in M8).
- **Kein `onUpgrade` in v1:** drift bricht bei unbekannten Upgrades ab, statt Daten anzufassen.
- **Schema-Dump:** `drift_schemas/gymlog/drift_schema_v1.json`. CHECK-Listen der Enum-Codes stehen absichtlich als
  Literale in `tables.dart`, damit alte Dumps eingefroren bleiben; ein Test prüft, dass sie zu den Enums passen.
  `test/data/db/schema_test.dart` vergleicht das Code-Schema mit dem Dump und schlägt fehl, wenn Tabellen ohne Migration
  geändert werden. Generierte Helfer unter `test/data/db/migrations/gymlog/generated/` (und `lib/data/db/database.steps.dart`) sind von der Analyse ausgenommen.
- **Demo-Daten** (deterministisch, Seed 42): 13 Übungen aller Typen (davon „Butterfly“ archiviert, mit Historie), Pläne
  „Oberkörper“/„Unterkörper“, ca. 20 % freie Trainings, 2 ausgelassene Wochen, gelegentlich übersprungene Übungen und
  Session-Notizen, Körpergewicht 82 → ca. 80,5 kg. „Demo-Daten erzeugen“ **ersetzt alle Daten** (auch eine laufende
  Session), Einstellungen bleiben. „Alle Daten löschen“ setzt auch die Einstellungen zurück. Parameter `weeks` (52) für
  den Performance-Check in M9.
- **Dev-Build-Erkennung:** `isDevBuild = !kReleaseMode` (debug und profile sind die DEV-App). `DevTools` verweigert in der
  Release-App zusätzlich selbst den Dienst (`StateError`), nicht nur die UI blendet aus.
- **SQLite-Bibliothek:** `sqlite3` 3.x bindet über einen Build-Hook eine vorkompilierte, per SHA-256 geprüfte
  `libsqlite3.so` beim **Build** ein (im APK für arm64/armv7/x86_64 geprüft). Zur Laufzeit wird nichts geladen.
- `build_runner` 2.17 ignoriert `--delete-conflicting-outputs` (Hinweis beim Lauf); der Befehl aus CLAUDE.md funktioniert trotzdem.
- `scripts/install-dev.sh` weckt das Display nicht: Bei gesperrtem Handy zeigen Screenshots den Sperrbildschirm und sind
  für die Prüfung unbrauchbar. Solche Screenshots werden sofort gelöscht (persönliche Benachrichtigungen).

**M2**
- **„Training starten“ schon in M2** (§6.1 gehört dazu): legt die Session nach Spezifikation an. Bis M3 zeigt der Tab
  eine schlichte Übersicht der laufenden Session (`active_session_placeholder.dart`, wird in M3 ersetzt). „Beenden“ dort
  verhält sich wie §6.3 ohne Sätze: „Keine Sätze erfasst. Training verwerfen?“ → löscht die Session.
- **Ziele beim Hinzufügen aus der Bibliothek:** Sätze = Standard-Satzanzahl, ohne Ziel-Wdh/-Dauer („3 Sätze“); anpassen per
  Tap → „Im Plan bearbeiten“. „Neue Übung anlegen“ fragt die Ziele direkt mit ab (§6.1).
- **Pause:** Im Übungsformular ist sie die Pause der Übung (gilt überall). In „Im Plan bearbeiten“ ist sie die
  plan-spezifische Abweichung, mit „Standard verwenden“ zurück auf die Übung/Einstellung.
- **Optionale Ziele per Stepper** statt Tastatur: „–“ = ohne Ziel; Ziel-Wdh 1–100 (Start 10), Ziel-Dauer in 5-s-Schritten
  (Start 30 s), Pause in 15-s-Schritten 0–10 min. Änderungen im Sheet werden sofort gespeichert (kein „Speichern“-Knopf).
- **„Zuletzt: …“** = Arbeitssätze der letzten abgeschlossenen Session, in der die Übung mindestens einen Satz hatte (egal
  welcher Plan). Formate: `60 kg × 10, 10, 8` (gleiches Gewicht), `60 × 10, 62,5 × 8` (wechselnd), `10, 9 Wdh`
  (Körpergewicht ohne Zusatz), `+10 kg × 8, 7`, `45, 40 s`, `1:30, 1:25 min`.
- **Übungsauswahl:** „Zuletzt verwendet“ = bis zu 6 nicht archivierte Übungen der jüngsten Sessions; enthaltene Übungen
  sind dort und in den Kategorien markiert und gesperrt. Kategorien in der Reihenfolge von §5, danach „Ohne Kategorie“.
  Suche ignoriert Groß-/Kleinschreibung und Umlaute (ü = u). Der Suchtext wird als Name in „Neue Übung anlegen“ übernommen.
- **Typ einer Übung mit Trainingshistorie ist gesperrt** (Formular + Repository), sonst passten alte Sätze nicht mehr zum Typ.
- **Löschen/Archivieren einer Übung** fragt nach und nennt, aus wie vielen Plänen sie entfernt wird.
- **Plan duplizieren** wählt die Kopie aus; wird der ausgewählte Plan gelöscht, ist „Frei“ ausgewählt.
- **Wischen zum Entfernen:** Der Eintrag verschwindet sofort aus der Liste (lokal), die Datenbank folgt; „Rückgängig“ setzt
  ihn mit gleicher id, Zielen und Position wieder ein. Die freie Liste lebt nur im Speicher und wird beim Start geleert.
- `ReorderableListView.onReorder` ist in Flutter 3.47 veraltet → `onReorderItem` (Index bereits korrigiert).
- Screenshots vom Handy werden vor dem Ansehen automatisch geprüft (Hintergrundfarbe der App); alles andere, z. B. der
  Sperrbildschirm, wird ungesehen gelöscht.

**M3**
- **Vorbefüllung §7.1 wörtlich:** Ab Satz 2 gelten immer die Werte des vorherigen Satzes *dieser* Session (Regel 1), auch
  wenn die letzte Session für Satz n andere Werte hatte. Nur Satz 1 kommt aus der letzten Session (Regel 2).
- **Leere Werte** (Gewicht bei `weight_reps` ohne Historie, Wdh/Dauer ohne Ziel): −/+ und „Satz speichern“ öffnen direkt
  die Zahleneingabe statt einer Fehlermeldung. Zahleneingabe: Komma oder Punkt; Dauer als Sekunden („90“) oder „1:30“.
- **Stepper:** Gewicht in Schritten von `incrementKg` (≥ 0; Körpergewicht bis −500 kg Unterstützung), Wdh 1–999, Dauer
  ±5 s. Werte werden sofort im Eingabefeld geführt, damit schnelle Doppel-Taps nicht verloren gehen.
- **Statuslogik:** Speichern in eine offene Übung macht sie aktiv. Ziel erreicht → `done` (+ ggf. `autoActivateNext`).
  „Überspringen“ ist immer möglich und behält vorhandene Sätze. „Übung beenden“ ab 1 Satz. „Wieder öffnen“ → aktiv; ist
  das Ziel schon erreicht, schließt der nächste Satz die Übung wieder (dafür gibt es „+1 Satz“). Satz löschen ändert den
  Status nicht; „Rückgängig“ (5 s) stellt dagegen alle Status exakt wieder her.
- **Als Nächstes:** Ohne aktive Übung wird die erste offene Übung nach der zuletzt abgeschlossenen markiert (blauer Rand +
  „Als Nächstes“), am Ende wieder von vorn.
- **Reorder in der Session:** Erledigte/übersprungene Kacheln haben keinen Griff und behalten ihren Platz; verschobene
  offene Übungen füllen die übrigen Plätze (Regel in `domain/session_rules.dart`, im Repository erneut geprüft).
- **Beenden:** Ohne Sätze → „Keine Sätze erfasst. Training verwerfen?“ (löscht). Mit offenen/aktiven Übungen →
  „N Übungen sind nicht abgeschlossen …“. Beim Beenden: ohne Sätze → `skipped`, offen/aktiv mit Sätzen → `done`.
- **AppBar der Session:** Planname, Timer (32 sp, ohne zusätzliche Systemschrift-Skalierung) und „Beenden“; kein Zahnrad
  (kein Platz auf 360 dp – Einstellungen über die anderen Tabs). Name und Timer teilen sich den Titel, damit auch ein
  13-h-Timer nicht überläuft. Die laufende Session zeigt auf anderen Tabs die Leiste „Training läuft – 42:13“
  (unter 1 h `m:ss`, sonst `h:mm:ss`) und einen Punkt am Training-Symbol.
- **Vergessene Session (> 12 h):** Abfrage beim App-Start und bei Rückkehr in den Vordergrund. „Fortsetzen“ fragt bis zum
  nächsten App-Start nicht erneut. „Beenden“ → Ende = letzter Satz + 5 min (ohne Sätze: Startzeit) → Zusammenfassung.
  „Verwerfen“ mit zweiter Bestätigung.
- **Zusammenfassung:** Übungen = Übungen mit mindestens einem Satz; Volumen gerundet auf ganze kg; Vergleich ±% mit der
  vorherigen beendeten Session **desselben Plans** (fehlt ohne Vorgänger oder bei Vorgänger-Volumen 0). Notiz wird beim
  Tippen (0,6 s verzögert) und bei „Fertig“ gespeichert; Systemzurück = „Fertig“.
- **Plan übernehmen:** Schalter nur, wenn sich Reihenfolge geändert hat oder Übungen hinzukamen. Übernimmt die Reihenfolge
  der Session; neue Übungen mit ihren Session-Zielen (Sätze auf 1–10 begrenzt); bisherige Ziele bleiben.
- **Als Plan speichern** (freies Training): neuer Plan mit den Übungen und Zielen der Session; die Session selbst bleibt im
  Verlauf ein freies Training. Der neue Plan wird für das nächste Training ausgewählt.
- Haptik nach „Satz speichern“ ist best effort; ein Fehler der Vibration zeigt nie eine Fehlermeldung (Satz ist gespeichert).
- Display anlassen, Pausentimer, Vorschlags-Chip, Rekorde und Übungsnotiz in der Kachel folgen mit M4.

**M4**
- **Pausentimer:** gilt nach dem zuletzt gespeicherten Satz der Session (egal welche Übung); Dauer = Pause der
  Session-Übung → der Übung → Standard. Ende = Zeitpunkt des Satzes + Dauer + ±15-s-Anpassungen. Die Anpassungen und
  „Überspringen“ leben nur im Speicher; nach einem Neustart läuft der Timer ohne Anpassungen aus der gespeicherten Zeit
  weiter. Die Leiste liegt über der Tableiste und ist auf allen Tabs sichtbar. Vibration (3 × kurz) nur, wenn die Pause
  in dieser App-Sitzung laufend gesehen wurde, die App im Vordergrund ist und `vibrationEnabled` gilt; „Pause vorbei“
  (grün) 10 s, Tippen blendet sie aus. Anzeige zählt aufgerundet herunter (1:30 … 0:01).
- **Display anlassen:** `wakelock_plus` während einer laufenden Session, wenn `keepScreenOn` gesetzt ist; sonst und beim
  Ende wird es freigegeben.
- **Steigerungsvorschlag:** „alle erfassten Arbeitssätze der letzten Session erreichen das Ziel und es sind mindestens
  `targetSets`“. Grundlage sind die Ziele der aktuellen Session-Übung. Der Vorschlag wird auf die vorbefüllten Werte
  angewendet (Gewicht + Steigerung, +1 Wdh, +5 s) und verschwindet nach Übernehmen oder „×“.
- **Rekorde:** chronologisch nach `completedAt` über alle Sessions; „strikt größer“ als alle früheren Arbeitssätze, auch
  derselben Session; in der Session mit dem ersten Satz der Übung nie. Beim Körpergewicht zählt jede Erhöhung des
  Zusatzgewichts (auch weniger Unterstützung, z. B. −20 → −10 kg). Die Rekord-Labels werden aus der Datenbank berechnet
  (bleiben nach Neustart, verschwinden bei „Rückgängig“). Zusammenfassung: je Übung und Rekordart der beste Wert der Session.
- **Übungsnotiz** in der aktiven Kachel: einzeilig; Tippen öffnet einen Dialog; gespeichert wird an der Übung (gilt überall).
- Geräte-Dienste (`lib/core/device.dart`) sind injizierbar; Tests nutzen Fakes und prüfen Vibration/Haptik/Display-an.

**M5**
- **Verlaufsliste:** nur beendete Sessions, neueste zuerst, Monatsgruppen nach lokalem Startdatum. Sätze = Arbeitssätze
  aller Übungstypen; Volumen nach §7.6 (nur `weight_reps`). Rekord-Pokal, wenn mindestens ein Satz der Session nach §7.7
  ein Rekord war (gleiche chronologische Berechnung wie live; die Markierung kann sich ändern, wenn ältere Sätze
  bearbeitet werden – sie wird immer aus den aktuellen Daten berechnet).
- **Datumsformat** „Di, 3.11.“ wie in §6.4 (intl liefert den Wochentag ohne Punkt).
- **Zeiten ändern:** Start und Ende per Datums- und Uhrzeitauswahl; Ende muss nach dem Start und nicht in der Zukunft
  liegen (Dialog und Repository prüfen). Sätze außerhalb der neuen Zeitspanne bleiben unverändert.
- **Detail:** Sätze antippen → derselbe Ändern/Löschen-Dialog wie in der Session; Löschen nummeriert die folgenden Sätze
  neu. „Aus Training entfernen“ (⋮ je Übung) löscht die Übung samt Sätzen aus dieser Session, mit Rückfrage.
  Notiz wird beim Tippen (0,6 s verzögert) und beim Verlassen gespeichert. Session löschen fragt mit Datum und Planname.

**M6**
- **Zeiträume:** 4 W = heute und die 27 Tage davor; 3 M / 1 J = gleicher Kalendertag 3 bzw. 12 Monate zurück + 1 Tag
  (am Monatsende begrenzt); „Alles“ ohne Grenze. Standard 3 M; die Auswahl wird nicht gespeichert.
- **Kennzahlen:** „Aktuell (Ø 7 Tage)“ = gleitender Durchschnitt am neuesten Eintrag (§7.8); „30 Tage“ = dieser Wert minus
  der Durchschnitt am letzten Eintrag, der mindestens 30 Tage vor dem neuesten liegt (fehlt sonst); Min/Max über die
  Messwerte im gewählten Zeitraum. Der Durchschnitt nutzt immer die ganze Historie.
- **Eingabe:** vorbefüllt mit dem neuesten Wert (eine Nachkommastelle, Komma oder Punkt), 20–400 kg, gerundet auf 0,1.
  Der Datum-Chip zeigt „Heute“ oder das gewählte Datum; die Auswahl erlaubt keine Zukunft und springt nach dem Speichern
  auf „Heute“ zurück. Gibt es für den Tag schon einen Eintrag: „Eintrag vom 3.11. überschreiben?“.
- **Liste:** neueste zuerst; Wischen löscht sofort mit „Rückgängig“ (Eintrag kommt mit gleicher id zurück); Tippen öffnet
  die Zahleneingabe für das Gewicht dieses Tages (das Datum bleibt).
- **Diagramm:** Messpunkte als Punkte, Ø 7 Tage als Linie (Scheibe Blau); mindestens zwei Einträge im Zeitraum, sonst ein
  Hinweis. Achsenbeschriftung nur an Intervallpunkten. Tooltip mit Datum und Wert.

**M7**
- **Performance:** Alle Statistiken zusammen (Kraftindex, Wochenvolumen, Heatmap, Serie, Kategorien, Rekorde und jede
  Übung × Metrik) brauchen mit 1 Jahr Demo-Daten **8,6 ms** pro Durchlauf (Debug/JIT im Test gemessen,
  `test/data/repositories/stats_repository_test.dart` prüft < 50 ms). Daher kein Isolate (`compute`) nötig.
- **Effektive Last (§7.3):** nächstgelegener Körpergewicht-Eintrag zum lokalen Session-Datum, davor oder danach; bei
  gleichem Abstand der frühere. Effektives 1RM ist nur definiert, wenn Körpergewicht + Zusatzgewicht > 0.
- **Kraftindex (§7.5):** Baseline = P der ersten Session (mit definiertem P > 0) der Übung; je ISO-Woche der beste P;
  Fortschreiben bis einschließlich 8 Wochen nach dem letzten Wert, danach fällt die Übung heraus, bis sie wieder trainiert
  wird. Wochen ohne einbezogene Übung werden ausgelassen. Der Zeitraum schneidet nur die Anzeige zu.
- **Übung-Tab:** Auswahl nur aus Übungen mit Daten, vorausgewählt die zuletzt trainierte. Kennzahlen beziehen sich auf den
  gewählten Zeitraum: Bestwert = höchster Punkt, Veränderung = letzter − erster Punkt (+ %), Trainings = Punkte.
  Rekordpunkte (rot) = Wert strikt größer als alle früheren Punkte dieser Metrik (gesamte Historie). Tabelle: die letzten
  10 Trainings im Zeitraum, neueste zuerst. Die gewählte Metrik wird je Übung gemerkt (nur im Speicher).
- **Gesamt-Tab:** Kraftindex und Körpergewicht teilen sich die Zeitachse (Zeitraumbeginn bzw. erste Trainingswoche bis
  heute); Körpergewicht als Ø-7-Linie. Wochenvolumen als Balken (Wochen ohne Training = 0). Heatmap immer die letzten 26
  Wochen, Farbintensität relativ zum höchsten Tag. „Ø Trainings pro Woche“ über den Zeitraum (ab Zeitraumbeginn oder
  erstem Training bis zur aktuellen Woche). Serie: Wochen in Folge mit Training bis jetzt; die laufende Woche ohne Training
  unterbricht sie noch nicht. Trainingsdauer als Punkte je Training; Sätze pro Kategorie als horizontale Balken
  (absteigend, inkl. „Ohne Kategorie“).
- Achsen zeigen nur Intervallbeschriftungen (keine zusätzlichen Min/Max-Labels, die sich sonst überlappen).

**M8**
- **CSV (§8.1):** UTF-8 ohne BOM, CRLF-Zeilenenden, Komma, Punkt als Dezimalzeichen (max. 2 Nachkommastellen, ganze Zahlen
  ohne „.0“), Booleans als `true`/`false`, Enum-Codes aus §5. `exercise_position` 1-basiert; `e1rm_kg` nur für
  `weight_reps` (Epley). `sessions.csv`: `n_exercises` = Übungen mit mindestens einem Arbeitssatz, `n_sets` = Arbeitssätze,
  `volume_kg` nach §7.6. Nur beendete Sessions. Dateiname mit lokalem Datum.
- **JSON-Backup (§8.2):** Feldnamen wie die Modellfelder (camelCase), Zeitpunkte als UTC-ISO-8601 („…Z“), `exportedAt`
  lokal mit Offset wie im Beispiel. Einstellungen werden mit gesichert **und beim Import wiederhergestellt**.
- **Validierung beim Import:** JSON-Objekt, `format`, `formatVersion` 1…unterstützt, alle Felder mit richtigem Typ,
  Enum-Codes, Datumsangaben, eindeutige ids, Namen (Groß-/Kleinschreibung inkl. Umlaute), Körpergewicht-Daten und
  Übung-je-Plan/Session, alle Verweise, höchstens eine laufende Session. Weitere Regeln (z. B. Ziel-Sätze 1–10) prüfen die
  CHECK-Constraints der Datenbank; dann wird die Transaktion vollständig zurückgerollt.
- **Import:** gesperrt während einer Session (auch im Dienst geprüft); vorher Sicherheitskopie des aktuellen Stands als
  Backup-JSON in `Dokumente/safety-copies/` (die 3 neuesten bleiben); danach `replaceAll` in **einer** Transaktion.
  Dateiauswahl ohne Typfilter (manche Android-Dateimanager kennen `.json` nicht); der Inhalt wird geprüft.
- **„Letztes Backup“** wird gesetzt, wenn das Teilen-Menü nicht abgebrochen wurde (Android meldet oft nur „unbekannt“)
  bzw. „Speichern unter …“ eine Datei geschrieben hat. CSV-Export zählt nicht.
- **Backup-Hinweis** in der Zusammenfassung, wenn die Erinnerung > 0 ist und das letzte Backup mehr als so viele Tage
  zurückliegt oder es noch keins gibt („Noch kein Backup erstellt“).
- **Einstellungen:** Standard-Pause in 15-s-Schritten (0–10 min), Backup-Erinnerung 0–365 Tage (0 = aus). Unter „Über“
  zusätzlich „Lizenzen“ (Flutter-Lizenzseite inkl. OFL der Schriften).
- Teilen/Speichern/Datei wählen/Dokumentenordner liegen hinter `FileGateway` (Fake in Tests). Das zusammengeführte
  Release-Manifest enthält weiterhin nur `VIBRATE` (+ interne AndroidX-Berechtigung), geprüft nach Aufnahme der Plugins.

- **M9 – Entscheidungen des Nutzers:** Superset-Sätze **abwechselnd** (A1 → B1 → Pause → A2 → B2 …); Rotation rückt
  **nur weiter, wenn die fällige Übung im beendeten Training mindestens einen Arbeitssatz hatte**; **keine
  Verschachtelung** (eine Übung ist entweder einzeln, im Superset oder in einer Rotation); Supersets **überall**
  (Plan, freie Liste, laufende Session), Rotationen nur in Plänen.
- **M9 Superset-Ablauf:** Nach jedem Satz wird immer die nächste Übung des Supersets aktiv, die den Satz dieser Runde
  noch nicht hat (unabhängig von „Nächste Übung automatisch aktivieren“); nach der letzten Übung einer Runde wieder die
  erste mit offenen Sätzen. Haben Übungen unterschiedlich viele Sätze, läuft die längere am Ende allein (mit Pause
  nach jedem Satz). „Überspringen“/„Übung beenden“ springen zur nächsten Übung mit offenen Sätzen. Ist das ganze
  Superset fertig, gilt wieder die normale Regel (Einstellung `autoActivateNext`). „Rückgängig“ stellt auch die aktive
  Übung wieder her.
- **M9 Pausentimer im Superset:** Pause nur nach dem letzten Satz einer Runde; Dauer = Pause des Supersets, ohne eigene
  Einstellung die Pause der Übung, die die Runde beendet (Session-Übung → Übung → Standard). Weiterhin aus der
  gespeicherten Satzzeit berechnet, also nach Neustart korrekt.
- **M9 Rotation:** Gespeichert sind fällige Übung (`rotationExerciseId`, ohne Fremdschlüssel: ungültig = erste Übung)
  und Zähler. Ins Training kommt nur die fällige Übung; die anderen sind ausgegraut („Später“). „Wechsel nach N
  Trainings“ 1–10. „Als Nächstes trainieren“ (Kachel antippen oder Menü) setzt den Zähler zurück. Freie Trainings und
  Trainings anderer Pläne bewegen die Rotation nicht. Gelöschte Trainings drehen die Rotation nicht zurück.
- **M9 Gruppen bearbeiten:** Neue Gruppe aus mindestens zwei Übungen der Liste, die noch in keiner Gruppe sind; die
  Übungen rücken an die Stelle der ersten und behalten ihre Reihenfolge. „Übung hinzufügen“ im Gruppenmenü fügt eine
  neue Übung aus der Bibliothek ans Ende der Gruppe (bereits enthaltene Einzelübungen: Gruppe auflösen und neu bilden).
  „Aus Superset/Rotation nehmen“ setzt die Übung direkt hinter die Gruppe; bleibt weniger als zwei Übungen übrig,
  wird die Gruppe aufgelöst. Wischen entfernt die Übung wie bisher aus dem Plan (mit „Rückgängig“); eine dabei leer
  gewordene Gruppe wird gelöscht, beim Rückgängig kommt die Übung dann einzeln zurück.
- **M9 Reihenfolge in der Session:** Ein Superset ist als Block verschiebbar, solange keine seiner Übungen erledigt
  oder übersprungen ist; innerhalb des Supersets gelten die bisherigen Regeln (nur offene/aktive verschiebbar). Ein
  Superset in der Session kann nur aus offenen Übungen gebildet werden.
- **M9 Plan übernehmen:** Reihenfolge, Supersets (inkl. Pause) und neue Übungen werden übernommen; Rotationen bleiben
  unverändert an der Stelle ihrer Übung. Plan-Übungen, die in der Session fehlen, rutschen ans Ende – dadurch zeigt die
  Zusammenfassung den Schalter dann auch an (vorher nicht). „Als Plan speichern“ übernimmt Supersets.
- **M9 Backup/CSV:** Backup-Format 2 mit `planGroups`, `sessionSupersets`, `groupId`, `supersetId`; Format-1-Dateien
  werden weiterhin gelesen (ohne Gruppen). Der CSV-Export bleibt wie in §8.1 (keine Gruppenspalten).
- **M9 Verlauf/Statistik:** Sätze werden weiter je Übung gezählt, Supersets/Rotationen ändern keine Kennzahl. Die
  Verlaufsdetails zeigen Supersets nicht als Rahmen.
- **M9 Kraftindex:** wird wie bisher bei jedem Öffnen aus der gesamten Historie berechnet. Wer „Im Kraftindex
  berücksichtigen“ abschaltet, nimmt die Übung damit auch rückwirkend heraus (Info-Text im Formular).
- **M9 Plan-Chips:** Auswahl wird sofort angezeigt und im Hintergrund gespeichert; die Liste zeigt beim Wechsel keinen
  kurzzeitigen Leerzustand mehr. Keine Bestätigungs-Snackbars beim Bilden/Auflösen von Gruppen (sie würden „Training
  starten“ verdecken; der Rahmen zeigt das Ergebnis).
- **M9 Farben:** Superset Orange (hell `#9E420A` auf `#FCE7D8`, dunkel `#F5A066` auf `#3B2A1E`), Rotation Grün
  (Platten-Grün-Familie); Kontraste per Test ≥ 4,5:1. Symbole: Kette (Superset), Kreispfeile (Rotation).
- **Ab 1.0:** Neue Funktionen sammelt der Nutzer in `docs/ROADMAP.md` (Versionen mit Status PLANNED/IN PROGRESS/
  FINISHED); umgesetzt wird eine Version erst auf ausdrücklichen Auftrag. Die Release-App war vor 1.0 nie installiert.
- **Skripte umbenannt (nach 1.0):** `host-setup.sh`, `host-setup-usb.sh` (PC), `phone-connect-wifi.sh`,
  `phone-connect-usb.sh`, `install-dev.sh`, `install-release.sh`, neu `build-release-apk.sh` (APK nach `dist/`).
- **Meilensteine:** Auf Wunsch eingeschoben als M9; der bisherige M9 (Feinschliff, 1.0.0) heißt jetzt M10.

- **M10 Startbild:** `LaunchTheme`/`NormalTheme` mit App-Hintergrund (`#E9ECEF` hell, `#1B1E21` dunkel) als Fenster-,
  Status- und Navigationsleistenfarbe und passend hellen/dunklen Systemsymbolen; Android 12+ zeigt das App-Icon auf
  einem Kreis in Icon-Farbe (sonst wäre die weiße Hantel auf Hellgrau unsichtbar). Kein eigenes Splash-Bild.
- **M10 Launcher-Icons:** eigenes Motiv (Hantel, „Platten und Eisen“). Release: weiß auf Plate Blue; DEV-App
  (debug und profile): Eisen auf Plate Yellow mit Schriftzug „DEV“ – die DEV-Ressourcen liegen in
  `android/app/src/debug/res` und `…/profile/res` und überschreiben nur Icon und Icon-Farbe. Adaptives Icon
  (Android 8+), themed Icon (Android 13+, `mipmap-anydpi-v33`), PNG für Android 7. Erzeugt mit dart:ui ohne
  zusätzliches Paket: `flutter test tool/icons/generate_launcher_icons_test.dart` (außerhalb von `test/`, läuft nicht in
  `check.sh`). `applicationId`, Signatur und Manifest unverändert. Die Release-APK konnte ich nicht bauen (Signatur
  aus `.secrets/`); geprüft per `aapt2` an der DEV-APK.
- **M10 Schriftskalierung:** Android erlaubt bis 200 %. Ziel: bis 200 % kein Überlauf, keine mitten im Wort
  umbrochenen Texte. Ausnahmen bewusst gedeckelt: Statistik-Tabs bei 150 % (drei kurze Wörter), Zahlen der großen
  Stepper/Timer waren schon fest (`NumberStyles`). Bei großer Schrift steht „Rückgängig“ in der Snackbar in einer
  eigenen Zeile (Flutter misst die Aktion ohne Skalierung). Der Test lädt die echten Barlow-Schriften; mit der breiten
  Standard-Testschrift würden Überläufe gemeldet, die es am Handy nicht gibt.
- **M10 Performance** (1 Jahr Demo-Daten, ~170 Trainings, Datenbankdatei mit WAL/`synchronous=FULL`, Container-CPU):
  Satz speichern inkl. Rekordprüfung Median 6 ms (max. 9 ms), Training starten 17 ms, beenden inkl. Rotation 4 ms,
  Session-Ansicht (Details + Rekordlabels) 10 ms, Zusammenfassung 11 ms, Verlaufsliste 40 ms, Statistik laden 38 ms
  + Berechnung 9 ms, „Zuletzt“ 2 ms, Backup laden/kodieren/prüfen 39 ms, CSV 22 ms, Import aller Daten 280 ms. Am Handy
  ist mit dem 3–5-Fachen zu rechnen; alles bleibt unter ~200 ms, Satz speichern unter ~50 ms. Kein Isolate nötig.
  Beobachtung: Verlauf und Statistik rechnen nach jedem gespeicherten Satz im Hintergrund neu, sobald ihr Tab einmal
  geöffnet war (Tabs bleiben erhalten) – mit ~40 ms unkritisch, sonst wäre das der erste Hebel.
- **M10 Leerzustände:** Neu „Noch keine Übungen in diesem Training …“ (leeres freies Training) und „Dieses Training
  enthält keine Übungen mehr.“ (Verlaufsdetail); alle übrigen bestanden schon und sind jetzt gemeinsam getestet.
- **1.0.0 Übungsbibliothek:** Die Liste steht als reines Dart in `lib/domain/exercise_library.dart` (Daten, keine
  UI-Texte, daher nicht in `strings_de.dart`; der Schriftzeichen-Test prüft die Namen mit). Nur eine **neu angelegte**
  Datenbank startet damit (`onCreate`); eine bestehende wird beim Öffnen nie verändert – also auch nicht die DEV-App
  auf dem Handy. Dafür gibt es in Einstellungen → Übungen das Symbol „Standardübungen hinzufügen“: fügt nur Übungen
  hinzu, deren Name noch nicht vergeben ist (Groß-/Kleinschreibung egal, archivierte zählen mit), eigene Übungen
  bleiben unverändert. Keine Schemaänderung, keine Migration. „Alle Daten löschen“ (DEV) leert auch die Bibliothek,
  „Backup wiederherstellen“ und „Demo-Daten erzeugen“ ersetzen sie wie bisher vollständig.
- **1.0.0 Bibliotheksinhalt:** Namen so, wie man sie im deutschen Studio sagt (teils englisch: „Hip Thrust“, „Face
  Pulls“), Gerät in Klammern, wo es mehrere Varianten gibt. Kategorien: Kreuzheben → Rücken, Rumänisches Kreuzheben,
  Hip Thrust und Kickbacks → Beine, Dips → Brust (Bankdips/Trizeps-Dips → Arme), Face Pulls/Reverse Butterfly →
  Schultern, Shrugs → Rücken, Ausdauergeräte (Laufband, Crosstrainer, Ergometer, Rudergerät, Stepper, Seilspringen)
  als Zeitübungen → Sonstiges. Unterstützte Klimmzüge/Dips am Gerät sind keine eigene Übung: Körpergewicht-Übung mit
  negativem Zusatzgewicht. Gewichtsschritte: Langhantel/SZ 2,5 kg, Kurzhantel 2 kg, Maschine 5 kg, Kabel 2,5 kg,
  Kettlebell 4 kg (je Übung änderbar). Keine eigene Pause, keine Notizen; Kraftindex nach Standardregel (Zeitübungen
  nicht). Ungenutzte Übungen beeinflussen Statistik und Kraftindex nicht.
- **Releases auf GitHub (ab 1.0.0):** Entscheidungen des Menschen (2026-11-05): lokal bauen und signieren (Schlüssel
  verlässt den PC nicht, kein GitHub Actions), nur 64-Bit-ARM-APK, Changelog deutsch für Nutzer plus automatische
  Commit-Liste, nur finale Releases, **GitHub-Zugang nur auf dem PC** (nicht im Container, Claude Code kann kein Release
  auslösen). `scripts/release.sh` läuft auf dem PC (bricht im Container ab, erkennt ihn an `/.dockerenv`) und nutzt
  dort git und `gh` des Menschen. Es prüft Branch `main`, sauberen Stand, Stand von GitHub, neue Version/Build-Nummer,
  Roadmap-Status `FINISHED` und den Changelog-Abschnitt, ruft dann per `docker compose exec` im Container
  `scripts/release-build.sh` auf (check.sh, APK bauen, Paket/Version/Architektur/Signatur prüfen). Beim ersten Release
  wird der Fingerabdruck des Zertifikats in `.github/signing-certificate.sha256` gespeichert (öffentlich unbedenklich,
  steht in jeder APK); später bricht der Build bei einem anderen Schlüssel ab. Erst nach „ja“: Changelog-Datum +
  Commits, Commit `chore(release): vX.Y.Z`, annotierter Tag, `git push --atomic` per SSH (`git@github.com:…`, unabhängig
  von der HTTPS-Adresse von origin). Die Release selbst legt der Mensch im Browser an (2026-11-07, Wunsch: nur SSH-Schlüssel,
  keine GitHub CLI): Das Skript öffnet `releases/new` mit Tag, Titel und – bis 6000 Zeichen Adresslänge – dem Text, sonst
  liegt der Text in der Zwischenablage (`wl-copy`/`xclip`) bzw. in `dist/`; die APK wird hineingezogen. Die
  Release-Schnittstelle von GitHub akzeptiert keine SSH-Schlüssel, nur Tokens. Die APK mit
  `--target-platform android-arm64` behält den `versionCode` (anders als `--split-per-abi`); geprüft an einer Debug-APK.
  `release-notes.sh` ist lesend und von Claude Code getestet; `release.sh` und `release-build.sh` darf Claude Code nicht
  ausführen, beide sind nur auf Syntax geprüft. GitHub zeigt Zeilenumbrüche im Release-Text an, daher stehen
  Changelog-Einträge in einer Zeile.
- **1.0.1 Versionen:** 1.0.0 wurde nie veröffentlicht; erste GitHub-Release ist 1.0.1 (Entscheidung des Menschen). Der
  Changelog-Abschnitt [1.0.1] enthält deshalb die komplette Funktionsübersicht plus „Geändert nach dem Test der
  Vorabversion 1.0.0“; einen eigenen Abschnitt [1.0.0] gibt es nicht.
- **1.0.1 Snackbars:** Regel: keine Bestätigung für etwas, das man ohnehin sieht. Geblieben: Fehler, „Alle
  Standardübungen sind schon vorhanden“, „Backup wiederherstellen“ während eines Trainings gesperrt, und Löschen mit
  „Rückgängig“ (Körpergewicht, Übung aus Plan/freier Liste, Training im Verlauf). Entfernt: „Satz gespeichert“ samt
  Rückgängig (Sätze sind jederzeit änderbar; `undoSave` bleibt im Repository), „Gespeichert.“, „Training verworfen.“,
  „Satz gelöscht.“, „… entfernt.“, „Plan … gelöscht.“, „… gelöscht/archiviert.“ (der Dialog sagt es vorher),
  „wiederhergestellt“, „Backup erstellt.“, „Export erstellt.“, „Backup wiederhergestellt.“, „N Übungen hinzugefügt.“.
  Löschen mit Bestätigungsdialog (Satz, Übung aus Training, Plan, Übung) hat keinen Rückgängig-Hinweis; nur das Training
  im Verlauf bekommt zusätzlich zum Dialog „Rückgängig“ (ausdrücklich gewünscht): `SessionRepository.delete` liefert
  alles Gelöschte, `restoreDeleted` fügt es mit denselben ids wieder ein (ein inzwischen gelöschter Plan wird entfernt,
  der Planname bleibt). Ursache für „muss man wegwischen“: Flutter hält Snackbars mit Aktion standardmäßig offen
  (`persist`); jetzt immer `persist: false`, 5 s.
- **1.0.1 „+ Plan“:** Der gelb-schwarze Streifen war Flutters Überlaufmarkierung (nur in der DEV-App sichtbar): Die
  Tastatur des Namensdialogs schrumpfte die Trainingsseite dahinter auf ~126 dp, zu wenig für Plan-Chips und „Training
  starten“. Die Seite hat kein eigenes Textfeld und passt sich der Tastatur nicht mehr an (`resizeToAvoidBottomInset:
  false`); Test mit schrittweise einfahrender Tastatur.
- **1.0.1 Ziehen von Gruppen:** Flutter entscheidet beim Ziehen über Ober- und Unterkante des gezogenen Elements; bei
  einem hohen Superset liegen die in verschiedenen Übungen, der Platz springt hin und her bzw. zurück. Lösung ohne
  eigene Liste: Beim Berühren des Gruppengriffs zeigt die Gruppe nur eine Zeile („Curls Hantel · Curls Seil“); Flutter
  misst das Element erst, wenn sich der Finger etwas bewegt hat, also klein – sie verhält sich dann wie eine einzelne
  Übung. Nach dem Loslassen wieder voll. Test zeigt: ohne die Änderung landet die Gruppe wieder an der alten Stelle.
- **1.0.1 Pausen-Vibration im Hintergrund:** Android lässt Apps im Hintergrund nur für Alarme, Anrufe und
  Benachrichtigungen vibrieren; ein Dart-Timer läuft im Hintergrund außerdem nicht verlässlich. Umsetzung ohne Paket und
  ohne Benachrichtigung: `android/.../RestAlarm.kt` (MethodChannel `de.gymlog.app/rest_alarm`, `AlarmManager.
  setExactAndAllowWhileIdle`, `BroadcastReceiver` vibriert mit Nutzung „Alarm“, gleiches Muster 3 × kurz). Die App plant
  den Alarm nur, wenn sie während einer laufenden Pause in den Hintergrund geht (Vibration und Pausentimer an), und
  hebt ihn beim Zurückkommen auf; war die Pause dann schon vorbei, vibriert die App nicht ein zweites Mal. Permissions:
  `USE_EXACT_ALARM` (Android 13+, bei Installation erteilt, keine Abfrage) und `SCHEDULE_EXACT_ALARM` nur bis
  Android 12 (`maxSdkVersion="32"`); hat der Nutzer exakte Alarme entzogen, kommt ein ungenauer Alarm. CLAUDE.md Regel 6,
  SPEC §3 und der Architekturtest sind angepasst. Wird die App im Hintergrund beendet, vibriert der Alarm trotzdem.
  Nur am Handy prüfbar; Dart-Seite mit Fake getestet.
- **1.0.1 Pause nach „Beenden“:** Riverpod 3 pausiert Provider-Updates für verdeckte Seiten (`TickerMode`). Die
  Zusammenfassung verdeckt die Hauptseite; kam die Meldung „Training beendet“ aus der Datenbank erst danach an (am
  Handy langsamer als im Test), lief die Pausenleiste unsichtbar weiter und vibrierte. Jetzt beendet „Beenden“ bzw.
  „Verwerfen“ die Pausen aller Sätze direkt im Timer-State, und die Vibration prüft diesen State frisch. Test: Pause
  läuft, Seite verdeckt, Pause beendet → keine Vibration (ohne Änderung: eine).
- **1.0.1 Backup-Erinnerung:** Hinweiskarte jetzt in Einstellungen → Daten (gleiche gelbe Karte mit „Backup
  erstellen“), nicht mehr in der Zusammenfassung. Standard 30 Tage nur in `AppSettings.defaults`; die SQL-Spalte behält
  ihren Default 14, weil eine Änderung eine Schemamigration wäre und alle Zeilen ohnehin mit den App-Standards angelegt
  werden. Bestehende Installationen (DEV-App) behalten ihren Wert.
- **1.0.1 Serie:** Logik unverändert (Wochen Mo–So mit mindestens einem Training; eine noch leere laufende Woche bricht
  die Serie nicht, eine ganz ausgefallene schon). Neu: eigene Karte mit großer Zahl und Flammensymbol, „Keine aktive
  Serie“, Hinweis „Trainiere diese Woche, um sie zu halten/eine neue zu starten.“, „Längste Serie: N Wochen · nicht
  aktiv“ bzw. „Deine längste Serie bisher“; `longestStreak` in der Domain. Reihenfolge: Kraftindex, Serie,
  Körpergewicht (immer), Wochenvolumen, Kalender, Dauer, Kategorien.
- **1.0.1 Automatisches Drehen:** Das Hochformat ist nur im Manifest festgelegt (`screenOrientation="portrait"`); eine
  App kann die System-Einstellung „Automatisch drehen“ ohne Sonderrechte gar nicht ändern, GymLog tut es nicht. Vermutlich
  wurde der Drehen-Knopf getippt, den Android in der Navigationsleiste anbietet, wenn das Handy gedreht wird. Keine
  Änderung; bei erneutem Auftreten bitte notieren, wann.
- **1.0.1 Systemschrift:** Läuft laut Handytest; der automatische Test bleibt, weitere Arbeit daran ist nicht geplant.
- **1.1.0 lbs-Scheiben:** Die Werte vom Menschen (38, 45, 59, 66, 100 kg) und seine Vorgaben (lbs-Werte ganzzahlig und
  durch 5 teilbar, kg ohne Komma, 15 lbs pro Scheibe) passen am besten zu: lbs-Werte 10, 25, 40, 55 … (+15), kg = auf
  ganze kg gerundet (85 → 39, 100 → 45, 115 → 52, 130 → 59, 145 → 66, 220 → 100). Vier der fünf Werte stimmen exakt; für
  38 gibt es keine Regel, die zugleich 66 trifft (38 braucht Abschneiden, 66 Runden) – der Mensch prüft die Scheibe
  am Gerät. Ein Grundgewicht ist nicht nötig: Die App bestimmt aus dem kg-Wert die nächste 5-lbs-Zahl und geht von dort
  15 lbs weiter; ein Wert zwischen zwei Scheiben springt zur nächsten echten. Gespeichert wird der angezeigte kg-Wert.
- **1.1.0 Standard-Steigerung:** 15 lbs für alle (neue Installationen und Bestand), weil es die App des Menschen ist;
  Freunde in anderen Studios stellen es an einer Stelle um. Neue Übungen bekommen „Standard“. Schritte in den
  Einstellungen: 0,5 kg bzw. 5 lbs; beim Umschalten der Einheit bleibt die Zahl.
- **1.1.0 Bestand (Entscheidung des Menschen):** Nur Standardübungen an Geräten und Kabeln werden auf „Standard“
  umgestellt (fest hinterlegte Namensliste `lib/domain/legacy_steps.dart`, gleiche Liste in der Bibliothek, per Test
  abgeglichen; Groß-/Kleinschreibung egal, nur Typ Gewicht × Wdh). Nicht: Lang-/Kurzhantel, Kettlebell, Eigengewicht,
  Hackenschmidt (meist Scheiben zum Auflegen), selbst angelegte Übungen. Bizepscurls, Trizepsdrücken und Trizepsdrücken
  über Kopf am Kabel: Stufen × 4,5 kg. Beinpresse gilt als Gerät mit Steckgewicht – falls sie im Studio Scheiben zum
  Auflegen hat, in der Übung auf „Eigene, kg“ stellen. Alte Backups (Format < 3) bekommen beim Wiederherstellen
  dieselbe Zuordnung.
- **1.1.0 Gespeicherte Sätze (Entscheidung des Menschen):** Beim Umstellen bleiben die kg-Werte unverändert; eine alte
  „40 kg“ erscheint bei Stufen à 4,5 kg als „Stufe 8,9 (40 kg)“, + und − springen zur nächsten ganzen Stufe. Ändert man
  später die kg pro Stufe, bleiben die kg ebenfalls. Nur bei „Stufen ohne kg“ steht die Stufennummer im Satz; der
  Wechsel zu oder von diesem Modus rechnet nach Rückfrage um (× bzw. ÷ kg pro Stufe) und wird ohne kg-Angabe
  abgelehnt. Stufen ohne kg zählen nicht zum Volumen (Verlauf, Zusammenfassung, Wochenvolumen, CSV `volume_kg`), ihre
  Statistik und Rekorde zeigen „Stufe“ statt kg; `e1rm_kg` im CSV bleibt dort leer.
- **1.1.0 Stufen nur für Gewicht × Wdh:** Bei Körpergewicht und Zeit ergibt „Stufe“ keinen Sinn; dort gibt es Standard
  und Eigene.
- **1.2.0 Entscheidungen des Menschen:** Update-Prüfung mit Link im Browser (kein Herunterladen in der App, keine
  Installationsrechte); Berechtigungen `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `INTERNET` (nur Update-Abfrage);
  alle vier Zusatz-Benachrichtigungen (Pause auf dem Sperrbildschirm, Training noch offen, Backup, Serie in Gefahr);
  Buchungslink in den Einstellungen, vorbelegt mit der optioffice-Seite des Studios, „Slot buchen“ öffnet sie.
- **1.2.0 Umsetzung Erinnerungen:** `flutter_local_notifications` 22.3.3 (23.x verlangt compileSdk 37, im Container ist
  SDK 36). Geplant wird mit absoluten UTC-Zeitpunkten (keine Zeitzonen-Datenbank nötig), jeweils für die nächsten 14 Tage;
  `ReminderSync` plant nach jeder relevanten Änderung (Pläne, Trainingstage, Einstellungen, Training, Sätze, Verlauf) und
  bei jeder Rückkehr in die App alles neu (alte geplante Erinnerungen im eigenen Id-Bereich werden vorher gelöscht). Nach
  einem Neustart stellt das Paket die geplanten Benachrichtigungen selbst wieder her. Die Logik ist reines Dart
  (`lib/domain/reminders.dart`) und getestet. Die Berechtigung fragt GymLog einmal beim ersten Start mit 1.2.0.
  Desugaring (`desugar_jdk_libs`) ist für das Paket nötig.
- **1.2.0 Regeln der Erinnerungen:** Abend vorher zur eingestellten Uhrzeit am Vortag; „vor dem Training“ X Minuten vorher,
  nicht wenn heute schon ein Training läuft; mehrere aktive Pläne am selben Tag erinnern jeweils einzeln; nur Zeitpunkte in
  der Zukunft. „Training noch offen“ 3 h nach dem letzten Satz (ohne Satz nach dem Start). Backup: 19 Uhr am Tag, an dem
  die Erinnerung fällig wird; schon überfällig → sonntags 19 Uhr (einmal pro Woche); ohne Trainings keine Erinnerung,
  ohne jedes Backup noch am selben Abend. Serie: Samstag 18 Uhr, wenn eine Serie läuft und diese Woche noch kein Training
  war. Die Motivationssprüche (32, deutsch/englisch, mit Robotik-/KI-/Software-Witzen) wechseln je Tag und Plan.
- **1.2.0 Pause auf dem Sperrbildschirm:** Geht die App während einer Pause in den Hintergrund, erscheint eine stille,
  feste Benachrichtigung mit Android-Countdown bis zum Pausenende; sie verschwindet 15 s danach von selbst bzw. beim
  Zurückkehren. Die Vibration kommt weiter vom Alarm aus 1.0.1 (funktioniert auch ohne Benachrichtigungsrecht).
- **1.2.0 Update-Prüfung:** Einmal pro 24 h beim Öffnen bzw. Zurückkehren eine GET-Anfrage an
  `api.github.com/repos/…/releases/latest` (nur `tag_name` wird gelesen, kein Konto, keine Daten). Neuere Version →
  einmal pro Version eine Benachrichtigung und dauerhaft ein Hinweis unter Einstellungen → Über mit „Herunterladen“
  (öffnet die Release-Seite im Browser). Offline oder Fehler → still, nächster Versuch beim nächsten Öffnen.
- **1.2.0 Trainingstage:** Neu angehakte Tage übernehmen die zuletzt gesetzte Uhrzeit (sonst 18:00). Beim Duplizieren
  werden Trainingstage nicht kopiert (sonst doppelte Erinnerungen). Inaktive Pläne bleiben auswählbar, nur ausgegraut.
  Backup-Format 4 enthält Trainingstage, „aktiv“ und die Benachrichtigungs-Einstellungen; Gerätezustand (Berechtigung
  gefragt, letzte Update-Prüfung) nicht.
- **1.2.0 Tests:** Das Synchronisations-Widget ist in den allgemeinen Oberflächentests abgeschaltet
  (`reminderSyncEnabledProvider`), weil echte Datei-Ein-/Ausgabe und simulierte Zeit sonst ineinandergreifen; eigene Tests
  prüfen es eingeschaltet.
- **1.2.1 Entscheidungen des Menschen:** ein gemeinsames Release 1.2.1 (1.2.0 nie veröffentlicht, Changelog-Abschnitt
  zusammengeführt); Einstellungen als Startseite mit Unterseiten; überall dieselbe Plan-Seite (auch langes Drücken auf
  einen Chip); „Frei“ abschaffen.
- **1.2.1 „Frei“:** Ausgewählt ist der zuletzt gewählte Plan, sonst (nie gewählt oder gelöscht) der erste. Ohne Pläne
  zeigt der Training-Tab einen Hinweis mit „Plan anlegen“ (scrollbar, damit nichts hinter der Tastatur überläuft – der
  Tastatur-Test hat das gefunden). Ein laufendes freies Training aus 1.2.0 und alte freie Trainings funktionieren
  weiter (Session, Verlauf, Statistik, „Als Plan speichern“ in der Zusammenfassung). Die Datenbank kennt Sessions ohne
  Plan weiterhin; nur die Oberfläche legt keine mehr an. `lastSelectedPlanId = null` bedeutet jetzt „erster Plan“.
- **1.2.1 Plan-Seite:** Eigene Route `/plan/:id` über allem, damit Einstellungen → Pläne und der Training-Tab dieselbe
  Seite öffnen. „Duplizieren“ ersetzt die Seite durch die der Kopie; „Löschen“ schließt sie. Nach dem Anlegen öffnet sich
  die Seite des neuen Plans (vorher ein Blatt nur mit Trainingstagen). Das Plan-Menü und das Drei-Punkte-Menü entfallen.
- **1.2.1 Einstellungen:** Abschnittsüberschriften größer, fett, in der Primärfarbe, mit Trennlinie. Stepper in den
  Einstellungen mit normaler Beschriftung (wie Schalter), im Übungsformular und in Dialogen weiter fett. Die gelbe
  Backup-Karte steht auf der Startseite und unter „Daten“, aber erst, wenn es Trainings gibt (vorher erschien „Noch kein
  Backup erstellt“ auch bei einer leeren App). Ein bekanntes Update steht als Untertitel von „Über“ in der Primärfarbe.
- **1.2.1 Update-Suche:** „Nach Updates suchen“ prüft bei jedem Antippen sofort (ohne 24-h-Grenze und auch, wenn die
  automatische Suche aus ist), ohne Benachrichtigung; Ergebnis: neueste Version / neue Version mit „Zur Release-Seite“ /
  keine Verbindung. Auch die Benachrichtigung führt zur Release-Seite („Tippe, um die Neuerungen anzusehen“); der Download
  bleibt Sache des Nutzers.

## Datenbank-Migrationen (ab Schema 2)

1. Tabellen in `lib/data/db/tables.dart` ändern, `AppDatabase.currentSchemaVersion` + 1.
2. `dart run build_runner build`
3. `dart run drift_dev make-migrations` → neuer Dump in `drift_schemas/gymlog/`, Schritt-Datei und Tests unter
   `test/data/db/migrations/`.
4. In `AppDatabase.migration` `onUpgrade: stepByStep(from1To2: …)` ergänzen – nur additiv, nie Drop/Recreate von Tabellen
   mit Nutzerdaten; Datenintegritätstest für den Schritt schreiben.
5. `dart format test/data/db/migrations`, dann `./scripts/check.sh`.

## Abhängigkeiten außerhalb von SPEC §2

| Paket | Zweck | Begründung | seit |
|---|---|---|---|
| `package_info_plus` | App-Version und Build-Nummer für „Über“ und das Backup-Feld `appVersion` | Version steht nur im Manifest; Flutter Community Plus, aktiv gepflegt, war bereits indirekt über `share_plus` enthalten | M8 |
| `flutter_local_notifications` 22.x | Erinnerungen und Pausen-Countdown als Android-Benachrichtigungen | Verbreitetes, aktiv gepflegtes Paket; offline, keine Analytics; 22.x, weil 23.x compileSdk 37 verlangt | 1.2.0 |
| `timezone` | Zeitpunkte für geplante Benachrichtigungen | Wird von flutter_local_notifications verlangt; genutzt nur als UTC | 1.2.0 |
| `url_launcher` | Buchungsseite und Release-Seite im Browser öffnen | Offizielles Flutter-Paket; GymLog selbst lädt dabei nichts | 1.2.0 |
| `flutter_localizations` (SDK) | Deutsche Material-Texte (DatePicker, Tooltips wie „Zurück“) | Für Locale `de_DE` in `MaterialApp` nötig, Teil des Flutter-SDK | M0 |

## Manuelle Tests am Handy

<!-- Pro Meilenstein eine kurze Checkliste, was der Mensch in der DEV-App ausprobieren soll. -->

### 1.2.2 DEV-App und Updates über GitHub
Nur, was live ausprobiert werden muss. Einmalig vorher: Token anlegen (README, „Einmalig: GitHub-Token“).
- [ ] PC: `./scripts/release-dev.sh` läuft durch; auf GitHub gibt es genau eine Vorab-Release „GymLog DEV …“, „Latest“
  bleibt 1.2.1.
- [ ] Handy: `gymlog-dev.apk` aus dieser Release im Browser laden und über die bisherige DEV-App installieren (klappt ohne
  Deinstallieren); Über zeigt die Version `1.2.2-dev.…` und unter „Testliste und Änderungen (DEV)“ diese Liste.
- [ ] Play Protect blockiert diese DEV-App nicht mehr als schädlich (höchstens der Hinweis „unbekannter Entwickler“).
- [ ] Update testen: auf dem PC `git commit --allow-empty -m "chore: test dev update"` und
  `./scripts/release-dev.sh --quick`. DEV-App öffnen (auch aus dem Hintergrund): Benachrichtigung und Update-Seite
  erscheinen; danach blauer Punkt am Zahnrad und bei „Über“.
- [ ] „APK herunterladen“: Browser lädt die APK, Datei antippen, Android installiert; DEV-App startet mit neuer Version,
  Daten sind noch da, der blaue Punkt ist weg.
- [ ] „Auf GitHub ansehen“ öffnet die Release im Browser; die Seite wirkt auch im Dunkelmodus gut lesbar.
- [ ] Release 1.2.2 mit `./scripts/release.sh`: Release erscheint ohne Browser mit Text und APK als „Latest“.
- [ ] Echte App: 1.2.2 wie gewohnt installieren; Play Protect blockiert nicht.

### 1.2.1 Verbesserungen
Nur, was am Handy angesehen werden muss; Abläufe sind automatisch getestet.
- [ ] Einstellungen: Startseite und Unterseiten wirken übersichtlich, Abschnitte klar getrennt (auch im Dunkelmodus).
- [ ] Langes Drücken auf einen Plan-Chip öffnet die Plan-Seite; „Frei“ ist weg.
- [ ] Über → „Nach Updates suchen“: zeigt „Du hast die neueste Version“ bzw. nach dem nächsten Release „Neue Version …“;
  „Zur Release-Seite“ öffnet GitHub im Browser.

### 1.2.0 Benachrichtigungen
Nur, was am Handy geprüft werden muss; Zeitpunkte, Texte, Einstellungen und Synchronisierung sind automatisch getestet.
- [ ] Erster Start nach dem Update: Android fragt einmal nach Benachrichtigungen → „Zulassen“.
- [ ] Einen Plan auf einen Trainingstag morgen stellen, Abend-Erinnerung in den Einstellungen auf in 2–3 Minuten setzen:
  Benachrichtigung „Morgen um …“ kommt pünktlich; „Slot buchen“ öffnet die Buchungsseite im Browser.
- [ ] „Vor dem Training“ mit Trainingstag heute in ~20 Minuten und Vorlauf 15 min: Benachrichtigung mit Spruch kommt.
- [ ] Handy neu starten, dann eine dieser Erinnerungen abwarten: kommt trotzdem.
- [ ] Satz speichern, App in den Hintergrund / Display sperren: Countdown „Pause“ auf dem Sperrbildschirm, Vibration am
  Ende, Benachrichtigung verschwindet kurz danach.
- [ ] Update-Hinweis (erst mit der nächsten Version prüfbar, weil 1.1.0 noch nicht nachsieht): Nach dem Release von
  1.2.1/1.3.0 die Release-App 1.2.0 öffnen → Benachrichtigung „GymLog … ist da“, Tippen öffnet die Release-Seite.

### 1.1.0 Gewichtseinstellungen
Nur, was sich am Handy bzw. im Studio prüfen lässt; Rechnung, Migration, Formular und Anzeige sind automatisch getestet.
- [ ] Nach dem Update der DEV-App (Migration auf Schema 3): Verlauf und Statistik unverändert; Latzug & Co. stehen in der
  Übung auf „Standard“, Bizepscurls am Kabel auf „Stufen“ mit 4,5.
- [ ] Im Studio an einem 15-lbs-Gerät: + und − ergeben genau die Zahlen auf den Scheiben (z. B. 45 → 52 → 59 → 66).
  Besonders prüfen: Steht auf der 85-lbs-Scheibe 38 oder 39, und bei 160 lbs 72 oder 73? Beinpresse: Steckgewicht?
- [ ] Am Seilzug mit Stufen: „Stufe 10 · 45 kg“ passt zur Scheibe 10; antippen der Zahl → „Stufe eingeben“.

### 1.0.1 Bugfixes (vor dem ersten Release)
In der **DEV-App** (nach `./scripts/install-dev.sh`). Die DEV-App behält ihre Daten und ihre Backup-Erinnerung.
- [ ] Pausen-Vibration im Hintergrund: Satz speichern, App wechseln (z. B. Startbildschirm) → zum Pausenende 3 × kurz.
  Dasselbe mit gesperrtem Display. Zurück in GymLog nach dem Ende: „Pause vorbei“, aber keine zweite Vibration.
- [ ] Zurück in GymLog **vor** dem Ende: die App vibriert wie bisher genau einmal.
- [ ] Vibration in den Einstellungen aus: auch im Hintergrund keine Vibration.
- [ ] Letzten Satz speichern, gleich „Beenden“: auf der Zusammenfassung keine Pausenleiste und keine Vibration, auch
  nicht nach Ablauf der Pause.
- [ ] Keine Hinweise mehr bei Satz speichern, Satz löschen, Training verwerfen, Körpergewicht speichern, Plan löschen,
  Backup/Export. Körpergewicht wegwischen → Hinweis mit „Rückgängig“, verschwindet nach ~5 s von selbst.
- [ ] Verlauf: Training löschen (Rückfrage) → Hinweis „Training gelöscht“ mit „Rückgängig“ → Training mit allen Sätzen
  wieder da.
- [ ] „+ Plan“: kein gelb-schwarzer Streifen hinter dem Dialog.
- [ ] Superset/Rotation am Griff oben rechts anfassen: Rahmen schrumpft auf eine Zeile mit den Übungsnamen; zwischen
  zwei einzelne Übungen schieben → landet dort; danach wieder vollständig. Kurz antippen ändert nichts.
- [ ] Superset: Untertitel „Pause wie bei letzter Übung“ in einer Zeile; ⋮ → „Pause einstellen“ → Dialog „Pause nach
  jeder Runde“ mit „wie bei letzter Übung“; +/− ändert die Größe des Dialogs nicht.
- [ ] Rotation: ⋮ → „Wechsel einstellen“ → kompakt „[−] 1 [+] Training“, bei 2 „Trainings“.
- [ ] Zusammenfassung ohne Backup-Hinweis. Einstellungen → Daten: gelbe Karte „Letztes Backup vor … Tagen“, wenn die
  Erinnerung fällig ist (DEV-App: dein bisheriger Wert); „Backup erstellen“ dort → Karte verschwindet.
- [ ] Statistik → Gesamt: Serie als zweite Karte (Flamme, „N Wochen in Folge“ bzw. „Keine aktive Serie“, längste Serie
  „nicht aktiv“); Körpergewicht direkt darunter ohne Schalter.
- [ ] „Über“: Version 1.0.1, Build 13.

**Danach: erstes Release** (auf dem PC, README „Neue Version veröffentlichen“) und echte App installieren
- [ ] Release 1.0.1 auf GitHub mit APK; Text = Changelog 1.0.1 mit Installationshinweisen.
- [ ] Release-App: Icon blau „GymLog“; Start ohne Trainings und Pläne, mit den 94 Standardübungen; Einstellungen ohne
  Entwickler-Bereich; Backup-Erinnerung 30 Tage; „Über“ zeigt 1.0.1. Ein Backup aus der DEV-App lässt sich hier
  wiederherstellen.

### Gesamt-Testliste Version 1.0 (am Handy abgearbeitet, 2026-11-06; Anmerkungen → 1.0.1)
Zuerst in der **DEV-App** (gelbes Icon „GymLog DEV“). Die Release-App war noch nie installiert und startet daher ohne
Daten (keine Migration nötig); sie wird erst nach bestandener Liste installiert.

**Installation und Aussehen**
- [ ] Launcher: „GymLog DEV“ gelb mit dunkler Hantel und „DEV“, neben „GymLog“ (blau, weiße Hantel); Android 13+ mit
  „Designsymbole“: beide einfarbig, DEV mit „DEV“.
- [ ] Start hell: kein weißer Blitz, Statusleisten-Symbole dunkel; Start dunkel: dunkler Hintergrund, helle Symbole.
- [ ] Hell/Dunkel/System in den Einstellungen wirkt sofort; große Systemschrift (auch Maximum): nichts überlappt,
  keine mitten im Wort getrennten Texte.
- [ ] Hochformat bleibt; Schrift ist Barlow; Zahlen springen beim Zählen nicht.

**Leerer Start** (Einstellungen → „Alle Daten löschen“)
- [ ] Training „Füge Übungen hinzu oder starte direkt.“, Verlauf/Statistik/Körper mit Hinweistexten; leeres freies
  Training starten → Hinweis, „Beenden“ → „Keine Sätze erfasst. Training verwerfen?“.
- [ ] Einstellungen → Übungen/Archiv/Pläne leer mit Hinweis; „+ Übung hinzufügen“ → „Noch keine Übungen …“ + „Neue
  Übung anlegen“.
- [ ] Einstellungen → Übungen → Symbol „Standardübungen hinzufügen“ (oben, neben dem Archiv) → „94 Übungen …“ →
  „Hinzufügen“: Liste gefüllt, Kategorie-Filter zeigen jeweils passende Übungen; erneut antippen → „Alle
  Standardübungen sind schon vorhanden“.

**Mit Demo-Daten** („Demo-Daten erzeugen“)
- [ ] Pläne: Chips ohne Haken, sofortiger Wechsel; Reihenfolge ziehen, wischen + Rückgängig, „Im Plan bearbeiten“,
  Long-Press-Menü (Umbenennen/Duplizieren/Löschen), „+ Plan“.
- [ ] Superset (orange) und Rotation (grün) in „Oberkörper“: verschieben, innen umsortieren, ⋮-Menü, ⓘ, „Als Nächstes
  trainieren“, neue Gruppen erstellen und auflösen.
- [ ] Training „Oberkörper“: Timer, Vorbefüllung, „Letztes Mal“, Vorschlag-Chip, Satz speichern (Vibration, Snackbar,
  Rückgängig), Rekord (rotes Aufleuchten), Superset-Wechsel ohne Pause, Pausenleiste nach der Runde (−15/+15,
  Überspringen, „Pause vorbei“ mit Vibration), Display bleibt an, Notiz zur Übung, Stoppuhr bei Plank.
- [ ] Andere Übung antippen, Reihenfolge ändern, „+1 Satz“, „Überspringen“, „Übung beenden“, „Wieder öffnen“,
  Satz ändern/löschen, „+ Übung hinzufügen“, Superset in der Session bilden.
- [ ] App wegwischen und neu öffnen: gleiche Session, aktive Übung, Pausenrest.
- [ ] „Beenden“ → Zusammenfassung: Dauer, Sätze, Volumen ±%, Rekorde, Plan übernehmen, Notiz, Backup-Hinweis →
  „Fertig“; die Rotation ist danach weitergerückt.
- [ ] Verlauf: Monate, Rekord-Pokal, Detail (Zeiten ändern, Notiz, Sätze ändern, Übung entfernen, Training löschen).
- [ ] Statistik: Zeitraum, Übung mit Metriken + ⓘ + Rekordpunkten + Kennzahlen, Gesamt (Kraftindex, Körpergewicht
  einblenden, Wochenvolumen, Kalender, Dauer, Kategorien), Rekorde → Tippen öffnet Übung; Tab öffnet ohne Verzögerung.
- [ ] Körper: Eintrag mit Komma, Überschreiben-Rückfrage, Diagramm mit Ø 7 Tage, Kennzahlen, wischen + Rückgängig.
- [ ] Übung bearbeiten (Typ gesperrt nach Training, ⓘ Kraftindex), archivieren/wiederherstellen, löschen.

**Daten**
- [ ] CSV exportieren (Teilen und „Speichern unter …“), Backup erstellen → „Letztes Backup“, „Alle Daten löschen“ →
  Backup wiederherstellen (Vorschau) → alles inkl. Supersets/Rotationen zurück; fremde Datei → Meldung, nichts ändert
  sich; während eines Trainings gesperrt.
- [ ] „Über“: Version 1.0.0, Build 12, Schemaversion 2, Lizenzen.

**Erste Installation der Release-App** (nach bestandener Liste, durch dich mit `scripts/install-release.sh`)
- [ ] Icon blau „GymLog“ neben „GymLog DEV“; Start ohne Trainings und Pläne, aber mit den 94 Standardübungen
  (Einstellungen → Übungen, „+ Übung hinzufügen“); Einstellungen ohne Entwickler-Bereich; „Über“ zeigt
  Version 1.0.0. Ein Backup aus der DEV-App lässt sich hier wiederherstellen (z. B. selbst angelegte Übungen/Pläne).

### 1.0.0 Übungsbibliothek (Nachtrag)
Die DEV-App hat schon eine Datenbank und bekommt die Bibliothek deshalb nicht automatisch.
- [ ] Mit deinen bisherigen DEV-Daten: Einstellungen → Übungen → „Standardübungen hinzufügen“ → Dialog nennt die Zahl
  der fehlenden Übungen → „Hinzufügen“ → Snackbar „… Übungen hinzugefügt.“; eigene Übungen mit gleichem Namen
  (z. B. „Bankdrücken“) sind nicht doppelt und unverändert; archivierte tauchen nicht wieder auf.
- [ ] Kategorien durchklicken (Brust … Sonstiges): Zuordnung und Typ-Symbol (Gewicht/Körpergewicht/Uhr) passen; fehlt
  dir eine Übung oder heißt sie im Studio anders, einfach melden oder selbst umbenennen.
- [ ] „+ Übung hinzufügen“ im Plan: Suche „curl“ findet alle Curl-Varianten; „Plank“ startet mit Stoppuhr,
  „Laufband“ ebenso.
- [ ] Eine Standardübung bearbeiten (z. B. Gewichtsschritt 1,25 kg) und eine ungenutzte löschen → „Standardübungen
  hinzufügen“ bietet genau diese eine wieder an.

### M10 Feinschliff
- [ ] Siehe Gesamt-Testliste; zusätzlich gezielt: Start hell/dunkel, beide Icons, Systemschrift auf Maximum
  (Training mit Pausenleiste, Statistik → Gesamt, Verlaufsdetail mit übersprungener Übung, Snackbar „Rückgängig“).


### M0 Grundgerüst
Am Pixel 4a (5G) per USB geprüft (`install-dev.sh` + Screenshot): Training-Tab im hellen Design, Barlow, Statusleiste lesbar.
Handy verbinden: per USB `./scripts/phone-connect-usb.sh` (einmalig vorher `./scripts/host-setup-usb.sh` auf dem Host),
per WLAN `./scripts/phone-connect-wifi.sh`; danach `./scripts/install-dev.sh`.
- [ ] App heißt im Launcher **„GymLog DEV“** und ist eine eigene App neben „GymLog“ (falls installiert, bleibt diese unberührt).
- [ ] Vier Tabs unten: Training, Verlauf, Statistik, Körper. Jeder zeigt Titel + Leerzustand; Wechsel ist sofort.
- [ ] Zahnrad oben rechts öffnet „Einstellungen“ ohne Tableiste; Zurück (Pfeil und Systemgeste) führt zum vorherigen Tab.
- [ ] Erneutes Tippen auf den aktiven Tab ändert nichts Sichtbares (springt zur Startseite des Tabs).
- [ ] Drehen des Handys: App bleibt im Hochformat.
- [ ] System auf Dunkelmodus umstellen: Hintergrund Eisen (fast schwarz), Tableiste etwas heller, aktiver Tab blau hinterlegt.
  Hellmodus: Hintergrund Stahl (hellgrau).
- [ ] Schrift ist Barlow (schmal, technisch – nicht die Standard-Roboto).
- [ ] Systemschrift auf groß stellen: nichts wird abgeschnitten.

### M1 Datenbank
Daten sind in den Tabs noch nicht sichtbar (ab M2). Geprüft wird, dass die Datenbank auf dem Handy funktioniert.
Vorher: Handy entsperren, dann `./scripts/phone-connect-usb.sh` und `./scripts/install-dev.sh`.
- [ ] App startet wie bisher im Training-Tab, ohne Fehlermeldung oder Absturz.
- [ ] Zahnrad → Einstellungen zeigt den Abschnitt „Entwicklung (nur GymLog DEV)“ mit „Demo-Daten erzeugen“ und
  „Alle Daten löschen“ (rot).
- [ ] „Demo-Daten erzeugen“ → Dialog → „Abbrechen“: nichts passiert.
- [ ] „Demo-Daten erzeugen“ → „Erzeugen“: nach höchstens ein bis zwei Sekunden Snackbar
  „Demo-Daten erzeugt: 42 Trainings, 586 Sätze, 60 Körpergewicht-Einträge.“ (am 3.11.; an anderen Tagen leicht anders).
- [ ] App komplett schließen (aus der Übersicht wischen), neu öffnen, erneut „Demo-Daten erzeugen“: gleiche Zahlen
  (Daten werden ersetzt, nicht verdoppelt).
- [ ] „Alle Daten löschen“ → Dialog mit rotem „Löschen“ → Snackbar „Alle Daten gelöscht.“

### M2 Übungen und Pläne
Vorher: Handy entsperren, `./scripts/phone-connect-usb.sh`, `./scripts/install-dev.sh`, in den Einstellungen „Demo-Daten erzeugen“.
- [ ] Training-Tab: Chips „Oberkörper“, „Unterkörper“, „Frei“, „+ Plan“. Ein Tap wählt; nach App-Neustart ist dieselbe Auswahl aktiv.
- [ ] Plan-Kacheln zeigen Typ-Symbol, Name, Ziel („3 × 8“, „3 × 60 s“) und „Zuletzt: …“ mit sinnvollen Werten.
- [ ] Griff rechts ziehen → Reihenfolge ändert sich und bleibt nach Neustart erhalten.
- [ ] Kachel nach links wischen → verschwindet, Snackbar „… entfernt“ mit „Rückgängig“ → kommt an gleicher Stelle zurück.
- [ ] Kachel antippen → „Im Plan bearbeiten“: Sätze, Ziel-Wdh, Pause mit −/+; Werte stehen nach Schließen in der Kachel.
  „Übung bearbeiten“ öffnet das Übungsformular.
- [ ] „+ Übung hinzufügen“: Suche (z. B. „bank“), „Zuletzt verwendet“, Kategorien; schon enthaltene sind ausgegraut mit Haken.
- [ ] „Neue Übung anlegen“ aus der Suche: Name ist vorbefüllt; Typ „Zeit“ wählen → Ziel-Dauer statt Ziel-Wdh; Speichern
  → Übung steht unten im Plan.
- [ ] „+ Plan“ → Name „Test“ → neuer leerer Plan ist ausgewählt („Dieser Plan hat noch keine Übungen.“). Gleicher Name
  nochmal → Fehlermeldung im Dialog.
- [ ] Chip lange drücken → Umbenennen / Duplizieren (Kopie wird ausgewählt) / Löschen (mit Rückfrage → „Frei“ ausgewählt).
- [ ] „Frei“: „Füge Übungen hinzu oder starte direkt.“; Übungen hinzufügen, wischen, Rückgängig.
- [ ] „Training starten“ → Übersicht „Läuft seit … Uhr“ mit den Übungen (vorläufig bis M3). „Beenden“ → „Keine Sätze
  erfasst. Training verwerfen?“ → „Weiter trainieren“ bleibt, „Verwerfen“ zurück zur Planung.
- [ ] Einstellungen → Übungen: Suche, Kategorie-Chips, „Neue Übung“, Tippen öffnet das Formular. Bei „Kniebeuge“ (hat
  Trainings) ist der Typ gesperrt mit Hinweis.
- [ ] Übung löschen (Papierkorb oben): neue Übung ohne Trainings → „löschen?“; „Bankdrücken“ → „archivieren?“ mit Hinweis
  auf Pläne. Archiv (Symbol oben rechts mit Zahl) → „Wiederherstellen“.
- [ ] Einstellungen → Pläne: Anzahl Übungen je Plan, Ziehen ändert die Chip-Reihenfolge im Training-Tab; ⋮-Menü
  Umbenennen/Duplizieren/Löschen.
- [ ] Systemschrift groß: Stepper-Werte und Kacheln bleiben lesbar, nichts überlappt.

### M3 Session-Kern
Vorher: `./scripts/install-dev.sh`, in den Einstellungen „Demo-Daten erzeugen“, Plan „Oberkörper“ wählen, „Training starten“.
- [ ] AppBar: „Oberkörper“, Timer läuft (h:mm:ss, Ziffern springen nicht), „Beenden“.
- [ ] Erste Übung ist aufgeklappt mit blauer Kante: „Satz 1 von 3“, Punkte, „Letztes Mal (…): …“, Gewicht und Wdh sind
  aus dem letzten Training vorbefüllt.
- [ ] −/+ ändern Gewicht (in Steigerungsschritten) und Wdh; Tippen auf die Zahl öffnet die Zahlentastatur („62,5“ und „62.5“).
- [ ] „Satz speichern“: kurze Vibration, Snackbar „Satz gespeichert“ mit „Rückgängig“; Satzzeile erscheint („1   62,5 kg × 8“).
  „Rückgängig“ entfernt ihn wieder.
- [ ] Satzzeile antippen → ändern oder löschen.
- [ ] Nach dem letzten Ziel-Satz klappt die Kachel zu (Haken, „3 Sätze, bestes …“); die nächste Kachel ist „Als Nächstes“
  markiert, aber nicht automatisch geöffnet. Erledigte Kachel antippen → Sätze + „Wieder öffnen“.
- [ ] Andere offene Übung antippen → wird aktiv; die vorige behält ihre Sätze („1/3“).
- [ ] Griff ziehen: offene Übungen lassen sich verschieben, erledigte bleiben an ihrem Platz.
- [ ] „+1 Satz“, „Überspringen“, „Übung beenden“ (erst ab einem Satz sichtbar).
- [ ] „+ Übung hinzufügen“ → Plank: Start → läuft sichtbar → Stopp übernimmt die Dauer; „Gewicht hinzufügen“ klappt ein
  Zusatzgewicht auf.
- [ ] Anderen Tab öffnen: oben „Training läuft – …“, Punkt am Training-Symbol; Tippen auf die Leiste führt zurück.
- [ ] App komplett schließen (aus der Übersicht wischen) und neu öffnen: gleiche aktive Übung, Sätze und Timer.
- [ ] „Beenden“ mit offenen Übungen → Rückfrage → Zusammenfassung: Dauer, Übungen, Sätze, Volumen mit ±% zum letzten
  „Oberkörper“; Schalter „Reihenfolge … übernehmen“ (erscheint, wenn du umsortiert oder Übungen hinzugefügt hast); Notiz;
  „Fertig“ → zurück zur Planung.
- [ ] Freies Training mit 1–2 Sätzen → Beenden → „Als Plan speichern“ → Name → Plan ist danach im Training-Tab ausgewählt.
- [ ] Training starten, ohne Satz „Beenden“ → „Keine Sätze erfasst. Training verwerfen?“.
- [ ] (Optional, dauert 12 h) Training starten, liegen lassen, am nächsten Tag öffnen → „Das Training vom … läuft noch.“
- [ ] Systemschrift groß: Kacheln, Stepper und Zusammenfassung ohne Überlappung.

### M4 Komfort im Studio
- [ ] Nach „Satz speichern“ erscheint über der Tableiste die gelbe Leiste „Pause 1:30“ mit Fortschritt; −15 s/+15 s
  ändern die Zeit; „Überspringen“ blendet sie aus. Die Leiste ist auch auf den anderen Tabs sichtbar.
- [ ] Bei 0: 3 × kurze Vibration, Leiste wird grün „Pause vorbei“ und verschwindet nach 10 s.
- [ ] App während der Pause schließen und wieder öffnen: Restzeit stimmt.
- [ ] Display geht während des Trainings nicht aus; nach dem Beenden wieder normal.
- [ ] Hat das letzte Training alle Ziel-Sätze geschafft, zeigt Satz 1 „Vorschlag: +2,5 kg“ (Körpergewicht: „+1 Wdh“,
  Zeit: „+5 s“). Tippen übernimmt, „×“ verwirft.
- [ ] Ein Satz über dem bisherigen Bestwert (z. B. Vorschlag übernehmen): Kachel leuchtet kurz rot, mittlere Vibration,
  Satzzeile mit rotem „Rekord“; Zusammenfassung listet „Neue Rekorde“. Beim allerersten Training einer neuen Übung keine Rekorde.
- [ ] Aktive Kachel: „Notiz hinzufügen“ → Text → erscheint einzeilig; Tippen bearbeitet.

### M5 Verlauf
- [ ] Verlauf ohne Trainings: „Noch keine Trainings. Starte dein erstes im Tab Training.“
- [ ] Mit Demo-Daten: Monatsüberschriften („Oktober 2026“), Einträge „Fr, 30.10. · Unterkörper“ mit Dauer, Sätzen,
  Volumen; Pokal bei Trainings mit Rekord.
- [ ] Eintrag antippen → Datum, Plan, „18:04 – 19:09 · 1:05 h“, Notiz, Übungen mit Sätzen und „Rekord“-Labels.
- [ ] Zeiten antippen → Start/Ende ändern; Ende vor Start wird abgelehnt.
- [ ] Satz antippen → ändern/löschen; Werte in der Liste aktualisieren sich.
- [ ] ⋮ an einer Übung → „Aus Training entfernen“ mit Rückfrage.
- [ ] Papierkorb → „Training vom Di, 3.11. („Oberkörper“) löschen?“ → Eintrag verschwindet aus dem Verlauf.

### M6 Körper
- [ ] Ohne Einträge: „Trage dein Gewicht ein, um den Verlauf zu sehen.“; Gewicht eingeben (Komma oder Punkt) → „Speichern“.
- [ ] Gleicher Tag erneut → „Eintrag vom … überschreiben?“.
- [ ] Datum-Chip „Heute“ → Kalender ohne Zukunft; anderer Tag speichern.
- [ ] Mit Demo-Daten: Punkte + blaue Ø-7-Linie, Achsen gut lesbar; 4 W / 3 M / 1 J / Alles ändern Diagramm und Min/Max.
- [ ] Kennzahlen „Aktuell (Ø 7 Tage)“, „30 Tage“ (mit Vorzeichen), „Min / Max“.
- [ ] Eintrag nach links wischen → gelöscht, „Rückgängig“ holt ihn zurück; Eintrag antippen → Gewicht ändern.
- [ ] Diagramm antippen/ziehen → Tooltip mit Datum und Wert.

### M7 Statistik
Vorher: „Demo-Daten erzeugen“.
- [ ] Ohne Trainings: Hinweistext statt Diagrammen.
- [ ] Übung: zuletzt trainierte Übung vorausgewählt; Auswahl öffnet Liste mit Suche; Metrik-Chips je Typ
  (Gewicht: 1RM/Maximalgewicht/Volumen; Körpergewicht: Max. Wdh/Gesamt-Wdh/Max. Zusatzgewicht/Effektives 1RM;
  Zeit: Max. Dauer/Gesamtdauer). Linie mit roten Rekordpunkten; Antippen zeigt Datum, Wert und Sätze.
- [ ] Bestwert, Veränderung (mit %), Trainings; Tabelle der letzten Trainings. 4 W / 3 M / 1 J / Alles ändert Diagramm
  und Kennzahlen.
- [ ] Gesamt: Kraftindex in % mit gestrichelter 100-%-Linie, „Durchschnitt über N Übungen“; Schalter „Körpergewicht
  einblenden“ zeigt darunter das Körpergewicht auf derselben Zeitachse.
- [ ] Wochenvolumen-Balken (Lücken in ausgelassenen Wochen), Trainingskalender (26 Wochen, Mo–So), „Ø … Trainings pro
  Woche“, „Serie: … Wochen in Folge“, Trainingsdauer, Sätze pro Kategorie.
- [ ] Rekorde: alle Übungen mit Bestwerten und Datum; Tippen springt in „Übung“ mit dieser Übung.
- [ ] Statistik-Tab öffnet ohne spürbare Verzögerung, auch nach „Demo-Daten erzeugen“.

### M8 Daten und Einstellungen
- [ ] Einstellungen → Training: Standard-Satzanzahl/-Pause ändern (neue Übungen/Pläne übernehmen sie), Pausentimer,
  Vibration, Display anlassen, Nächste Übung automatisch aktivieren – jeweils im Training ausprobieren.
- [ ] Darstellung System/Hell/Dunkel wirkt sofort.
- [ ] „CSV exportieren“ → „Teilen“ (z. B. an dich selbst mailen) und „Speichern unter …“; ZIP enthält vier CSV-Dateien,
  die sich in einer Tabellenkalkulation öffnen lassen (Komma als Trenner, Punkt als Dezimalzeichen).
- [ ] „Backup erstellen“ → „Speichern unter …“ in „Downloads“; danach steht „Letztes Backup: …“ mit Datum und Uhrzeit.
- [ ] „Alle Daten löschen“ (Dev) → „Backup wiederherstellen“ → die gespeicherte Datei wählen → Vorschau mit Anzahl
  Trainings, Zeitraum und Körpergewicht-Einträgen → „Wiederherstellen“ → alles ist wieder da (Verlauf, Statistik, Pläne).
- [ ] Eine beliebige andere Datei wählen → verständliche Meldung, nichts ändert sich.
- [ ] Während eines Trainings ist „Backup wiederherstellen“ ausgegraut.
- [ ] Backup-Erinnerung auf 1 Tag, Training beenden → Zusammenfassung zeigt den gelben Hinweis mit „Backup erstellen“.
- [ ] „Über“: App-Version, Build-Nummer, Schemaversion 1, Lizenzen. (Ab M9: Schemaversion 2.)

### M9 Verbesserungen
Vorher: Version 0.9 mit echten Daten ist auf dem Handy? Die DEV-App hat eigene Daten; beim Installieren von 0.10 wird
ihre Datenbank von Schema 1 auf 2 migriert – vorhandene Trainings/Pläne müssen danach unverändert da sein.
- [ ] Nach dem Update: Verlauf, Statistik, Pläne und Körpergewicht sind unverändert; „Über“ zeigt Schemaversion 2.
- [ ] „Alle Daten löschen“ → „Demo-Daten erzeugen“: „Oberkörper“ zeigt ein **oranges Superset** (Schulterdrücken +
  Rudern am Kabel, „Pause 1:30 min nach jeder Runde“) und eine **grüne Rotation** (Bizepscurls/Hammercurls, eine
  „Ist dran“, die andere ausgegraut „Später“).
- [ ] Plan-Chips: kein Haken mehr, gewählter Chip blau gefüllt, Wechsel ist sofort und ruckelfrei, Liste flackert nicht.
- [ ] Superset am Griff oben rechts verschieben: wandert als Ganzes. Innerhalb über die Griffe der Übungen umsortieren.
- [ ] Unter „+ Übung hinzufügen“: „Superset erstellen“ → zwei Übungen ankreuzen → Rahmen erscheint an der Stelle der
  ersten. ⋮-Menü: Pause einstellen (wird im Untertitel angezeigt), Übung hinzufügen, Auflösen. ⓘ erklärt das Superset.
- [ ] „Rotation erstellen“ (nur in Plänen, nicht bei „Frei“) → zwei Übungen. Ausgegraute Übung antippen → „Als
  Nächstes trainieren“ → sie ist jetzt dran. ⋮-Menü → „Wechsel nach … Trainings“ = 2 → Untertitel ändert sich, „Ist dran
  · noch 2 Trainings“.
- [ ] Training „Oberkörper“ starten: nur die fällige Curl-Übung ist im Training. Superset-Rahmen mit „Runde 1 von 3“.
  Schulterdrücken Satz speichern → Rudern wird automatisch aktiv, **keine** Pausenleiste. Rudern Satz speichern →
  Schulterdrücken aktiv, gelbe Pausenleiste mit der Superset-Pause, Untertitel „Runde 2 von 3“.
- [ ] „Rückgängig“ nach einem Superset-Satz: Satz weg, vorherige Übung wieder aktiv.
- [ ] In der Session: „Superset erstellen“ aus zwei offenen Übungen (z. B. Dips + Curls) → Rahmen erscheint; ⋮ →
  „Aus Superset nehmen …“, „Auflösen“.
- [ ] Training beenden (die Curl-Übung hatte Sätze) → im Training-Tab ist jetzt die andere Curl-Übung „Ist dran“.
  Nächstes Training die Curl-Übung überspringen → Rotation bleibt stehen.
- [ ] Zusammenfassung nach geändertem Superset: Schalter „Reihenfolge, Supersets und neue Übungen … übernehmen“ → an →
  „Fertig“ → Plan zeigt die neue Gruppierung.
- [ ] Freies Training: zwei Übungen hinzufügen, „Superset erstellen“ (kein „Rotation erstellen“), starten → Superset in
  der Session.
- [ ] Statistik → Übung: ⓘ rechts neben den Metrik-Chips erklärt die gewählte Metrik (1RM mit Epley-Beispiel, Volumen
  = insgesamt bewegtes Gewicht …). Gesamt: ⓘ bei Kraftindex, Wochenvolumen, Trainingskalender. Rekorde: ⓘ oben rechts.
- [ ] „Veränderung“: Prozentwert steht immer vollständig in der zweiten Zeile, z. B. „+14,6 kg“ / „(+13 %)“.
- [ ] Übung anlegen/bearbeiten: ⓘ neben „Im Kraftindex berücksichtigen“ erklärt die rückwirkende Neuberechnung.
- [ ] Backup erstellen und wiederherstellen: Supersets, Rotationen (inkl. fälliger Übung) sind danach wieder da.
- [ ] Dunkelmodus und große Systemschrift: Rahmen, Untertitel und die beiden „… erstellen“-Buttons bleiben lesbar.

