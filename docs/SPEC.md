# GymLog – Spezifikation

Version 1.0 der Spezifikation. Verbindlich für die Umsetzung. Abschnittsnummern werden in `CLAUDE.md` und `PROGRESS.md` referenziert.

---

## 1. Ziel und Rahmen

- Private Android-App für **eine Person**, die im Fitnessstudio parallel zum Training ihren Plan abarbeitet und Sätze erfasst.
- **Rein lokal:** keine Konten, kein Server, keine Netzwerkzugriffe. Daten liegen in SQLite auf dem Handy, Export/Backup über Dateien.
- **Nutzungssituation:** Handy in einer Hand zwischen zwei Sätzen, Puls hoch, Finger evtl. verschwitzt, wechselndes Licht.
  Daraus folgen: große Touch-Ziele (mind. 48 dp, Hauptaktionen mind. 56 dp hoch), hohe Kontraste, wenige Taps.
  Ziel: Ein Satz, dessen vorbefüllte Werte stimmen, ist mit **einem Tap** erfasst.
- **Datensicherheit vor Features:** Kein Datenverlust durch App-Kill, Akku leer, Updates oder Schemaänderungen.
- Sprache der Oberfläche: Deutsch. Einheit: kg. Zahlenformat de_DE. Nur Hochformat.

## 2. Technik-Stack

- Flutter 3.47.x stable, Dart. Nur Android-Plattform anlegen.
- Pakete (jeweils aktuelle stabile Version):

| Paket | Zweck |
|---|---|
| `flutter_riverpod` | State-Management (ohne Codegen) |
| `drift`, `drift_flutter`; dev: `drift_dev`, `build_runner` | SQLite mit Typen, Migrationen, reaktiven Queries |
| `go_router` | Navigation, `StatefulShellRoute` für die Tabs |
| `fl_chart` | Diagramme |
| `intl` | Zahlen-/Datumsformat de_DE |
| `share_plus` | Teilen-Menü für Export/Backup |
| `file_picker` | Backup-Datei wählen, „Speichern unter …“ |
| `archive` | ZIP für den CSV-Export |
| `path_provider` | App-Verzeichnisse |
| `wakelock_plus` | Display bleibt während der Session an |
| `vibration` | Vibrationsmuster am Ende der Pause |
| dev: `flutter_lints` | Lints |

- Schriften als Assets (siehe §9), keine Laufzeit-Downloads.

## 3. Projekt- und Build-Konfiguration

- Dart-Paketname `gymlog`. Android `namespace` und `applicationId`: **`de.gymlog.app`** (nach der ersten Installation nie wieder ändern).
- Build-Typ `debug`: `applicationIdSuffix ".dev"`, App-Name **„GymLog DEV“**, eigenes Launcher-Icon-Farbschema (unterscheidbar).
  Build-Typ `release`: App-Name **„GymLog“**. App-Name über `resValue`/String-Ressource je Build-Typ.
  Damit sind Entwicklungs-App und echte App zwei getrennte Apps mit getrennten Daten.
- Release-Signatur: liest `../.secrets/key.properties` (relativ zum `android/`-Ordner; Felder `storeFile`, `storePassword`,
  `keyAlias`, `keyPassword`; `storeFile` ist relativ zu `.secrets/`). Fehlt die Datei, bricht ein Release-Build mit klarer Meldung ab
  („Signaturschlüssel fehlt – siehe README, Schritt 4“). Kein Fallback auf Debug-Signatur für Release.
- Debug-Signatur: Standard-Debug-Keystore unter `~/.android` (liegt im Docker-Volume).
- Manifest: Permission `VIBRATE`; ab 1.0.1 zusätzlich `USE_EXACT_ALARM` und `SCHEDULE_EXACT_ALARM` (nur Android 12) für die
  Pausen-Vibration im Hintergrund (§6.2.1); ab 1.2.0 `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` (Erinnerungen, nach
  Neustart neu geplant) und `INTERNET` nur für die tägliche Abfrage der neuesten GitHub-Release (abschaltbar).
- Benachrichtigungen (ab 1.2.0, alle einzeln abschaltbar unter Einstellungen → Benachrichtigungen): Abend vorher (Standard
  20:00) mit Knopf „Slot buchen“ (öffnet die Buchungsseite im Browser), vor dem Training (Standard 60 min) mit
  Motivationsspruch, Pause als Countdown auf dem Sperrbildschirm, „Training noch offen“ 3 h nach dem letzten Satz,
  Backup fällig (19 Uhr am Fälligkeitstag, danach sonntags), „Serie in Gefahr“ (Samstag 18 Uhr ohne Training in der
  Woche), neue Version auf GitHub (einmal je Version; Tippen öffnet die Release-Seite im Browser).
- Pläne (ab 1.2.0): `active` (Standard an) und Trainingstage `plan_schedules` (Wochentag 1–7, Uhrzeit); nur aktive Pläne
  erinnern, inaktive sind in der Chip-Leiste ausgegraut. Nach dem Anlegen eines Plans öffnet sich „Trainingstage und
  Uhrzeit“. `android:allowBackup` bleibt auf dem Standard (aktiv) als zusätzliches Sicherheitsnetz.
  Activity auf Hochformat fixiert.
- Version in `pubspec.yaml` als `x.y.z+build`; Build-Nummer bei jedem Meilenstein erhöhen.
- `.gitignore` enthält zusätzlich zu den Flutter-Einträgen: `.secrets/`, `.env`, `build/`.

## 4. Architektur

```
lib/
  main.dart                  App-Start, ProviderScope
  app.dart                   MaterialApp.router, Themes, Locale de_DE
  core/
    l10n/strings_de.dart     alle UI-Texte
    theme/                   Farben, Typografie, ThemeData hell/dunkel
    format/                  kg-, Zeit-, Datumsformatierung, Zahlen-Parsing (Komma/Punkt)
    clock.dart               Clock-Abstraktion + Provider
    router.dart              go_router-Konfiguration
  data/
    db/                      drift: Tabellen, Database, DAOs, Migrationen
    repositories/            ExerciseRepo, PlanRepo, SessionRepo, BodyWeightRepo, SettingsRepo
    io/                      CSV-Export, JSON-Backup/-Import (nutzt domain/serialization)
    demo/                    Demo-Daten-Generator (nur Dev-Build)
  domain/                    reines Dart, keine Flutter-Imports
    models/                  unveränderliche Modelle/Enums (ExerciseType, Category, …)
    prefill.dart             §7.1
    progression.dart         §7.2
    metrics.dart             §7.3–7.6, 7.8
    records.dart             §7.7
    strength_index.dart      §7.5
    calendar.dart            ISO-Wochen, lokale Tage
    serialization/           CSV-Zeilen, Backup-JSON
  features/
    training/                Tab Training (Planansicht + aktive Session, Zusammenfassung)
    history/                 Tab Verlauf
    stats/                   Tab Statistik
    body/                    Tab Körper
    settings/                Einstellungen, Übungen, Pläne, Daten
  widgets/                   geteilte Widgets (Stepper, Kacheln, Leerzustände, Chart-Hüllen)
test/                        spiegelt lib/; domain/ mit Tabellentests
```

- Repositories liefern `Stream`s (drift `watch`), die UI rendert reaktiv.
- Statistikberechnungen sind reine Funktionen auf geladenen Daten. Dauert eine Berechnung spürbar (> ~50 ms mit Demo-Daten),
  in einem Isolate rechnen (`compute`).
- Zeitpunkte als UTC speichern. Tagesbezogene Werte (Körpergewicht) als lokales Datum `YYYY-MM-DD`.
  Session-Datum = lokales Datum von `startedAt`. Wochen = ISO-Wochen (Montag bis Sonntag), lokale Zeit.

## 5. Datenmodell (drift, `schemaVersion` 1)

**`exercises`** – Übungsbibliothek
- `id` int PK · `name` text, eindeutig (Groß-/Kleinschreibung ignoriert) · `type` text: `weight_reps` | `bodyweight` | `timed`
- `category` text, nullable: `chest` | `back` | `legs` | `shoulders` | `arms` | `core` | `full_body` | `other`
  (UI: Brust, Rücken, Beine, Schultern, Arme, Rumpf, Ganzkörper, Sonstiges)
- `incrementKg` real, Standard 2.5 · `restSec` int nullable (Überschreibt Standardpause)
- Ab Schema 3 (1.1.0) Gewichtsschritte: `stepMode` text `standard` | `kg` | `lbs` | `levels` · `incrementLbs` real
  (Standard 15) · `levelKg` real nullable. `standard` folgt der Standard-Steigerung der Einstellungen; `lbs` = Geräte mit
  lbs-Scheiben (lbs-Werte durch 5 teilbar, gespeichert und angezeigt wird der auf ganze kg gerundete Wert, z. B. 100 lbs =
  45 kg, 115 lbs = 52 kg); `levels` = nummerierte Stufen, mit `levelKg` als kg gespeichert und „Stufe 10 (45 kg)“
  angezeigt, ohne `levelKg` wird die Stufennummer gespeichert (zählt nicht zum Volumen).
- `includeInStrengthIndex` bool (Standard: true für `weight_reps`/`bodyweight`, false für `timed`)
- `notes` text, Standard leer (z. B. „Sitzhöhe 4, Griff eng“) · `archived` bool · `createdAt`

**`plans`** – `id` · `name` eindeutig · `position` int (Reihenfolge der Plan-Chips) · `createdAt`

**`plan_exercises`** – `id` · `planId` FK (cascade) · `exerciseId` FK (restrict) · `position` int ·
`targetSets` int (1–10) · `targetReps` int nullable · `targetDurationSec` int nullable · `restSec` int nullable.
Eine Übung höchstens einmal pro Plan.

**`sessions`** – `id` · `planId` FK nullable (set null) · `planNameSnapshot` text nullable (Name zum Zeitpunkt des Trainings;
null = freies Training) · `startedAt` UTC · `endedAt` UTC nullable (**null = aktive Session**) · `notes` text.
Es darf höchstens eine aktive Session geben (im Repository erzwingen).

**`session_exercises`** – `id` · `sessionId` FK (cascade) · `exerciseId` FK (restrict) · `position` int · `targetSets` ·
`targetReps` nullable · `targetDurationSec` nullable · `restSec` nullable · `status` text: `pending` | `active` | `done` | `skipped` ·
`completedAt` nullable. Eine Übung höchstens einmal pro Session.

**`set_entries`** – `id` · `sessionExerciseId` FK (cascade) · `setIndex` int (ab 1) ·
`weightKg` real nullable (`weight_reps`: Pflicht, ≥ 0; `bodyweight`: Zusatzgewicht, Standard 0, negativ = Unterstützung;
`timed`: optionales Zusatzgewicht) · `reps` int nullable (Pflicht ≥ 1 für `weight_reps`/`bodyweight`) ·
`durationSec` int nullable (Pflicht ≥ 1 für `timed`) · `isWarmup` bool, Standard false (in v1 ohne UI, für später reserviert) ·
`completedAt` UTC.

**`body_weight_entries`** – `id` · `date` text `YYYY-MM-DD` eindeutig · `weightKg` real · `createdAt`

**`app_settings`** – genau eine Zeile (`id` = 1):
`defaultSets` (3) · `defaultRestSec` (90) · `restTimerEnabled` (true) · `vibrationEnabled` (true) · `keepScreenOn` (true) ·
`autoActivateNext` (false) · `themeMode` (`system` | `light` | `dark`) · `lastSelectedPlanId` nullable (null = Frei; ab 1.2.1 null/gelöscht = erster Plan) ·
`lastBackupAt` nullable · `backupReminderDays` (14, ab 1.0.1 Standard 30; 0 = aus) · ab 1.1.0 `defaultStep` real
(Standard 15) und `defaultStepUnit` `kg` | `lbs` (Standard `lbs`)

Regeln:
- Übungen, die in Sessions vorkommen, werden nicht gelöscht, sondern archiviert. Unbenutzte dürfen gelöscht werden.
- Plan löschen lässt den Verlauf unverändert (`planNameSnapshot`).
- Migrationen ab Version 2: Schema-Dump in `drift_schemas/`, generierte Migrationstests, niemals destruktiv.

## 6. Navigation und Screens

Shell mit `NavigationBar`, vier Tabs: **Training**, **Verlauf**, **Statistik**, **Körper**.
Jeder Tab hat in der AppBar ein Zahnrad → **Einstellungen** (eigene Route über der Shell).
Läuft eine Session und ist ein anderer Tab offen, trägt das Training-Icon einen Punkt und oben erscheint eine schmale Leiste
„Training läuft – 42:13“ (Tap → Training-Tab).

### 6.1 Training – keine aktive Session

- **Plan-Leiste** oben: horizontale Chips mit allen Plänen in `position`-Reihenfolge, dann „+ Plan“
  (Namensdialog → neuer leerer Plan, wird ausgewählt, ab 1.2.1 öffnet sich danach die Plan-Seite). Auswahl wird in
  `lastSelectedPlanId` gemerkt. Long-Press auf Plan-Chip → ab 1.2.1 die Plan-Seite (siehe §6.7).
- **Ab 1.2.1 gibt es kein „Frei“ mehr:** Jedes Training startet aus einem Plan. Ohne Pläne zeigt der Tab „Noch kein
  Trainingsplan …“ mit „Plan anlegen“. Frühere freie Trainings bleiben im Verlauf und in der Statistik unverändert.
- **Liste** der Plan-Übungen (`ReorderableListView`). Kachel kompakt: Typ-Icon, Name, Ziel („3 × 10“, „3 × 45 s“, „3 Sätze“),
  Referenz „Zuletzt: 60 kg × 10, 10, 8“ (aus der letzten Session mit dieser Übung, egal welcher Plan), Drag-Handle.
  - Reorder ändert den Plan sofort (persistiert).
  - Wisch nach links: aus Plan entfernen, Snackbar mit „Rückgängig“.
  - Tap: Bottom Sheet „Im Plan bearbeiten“ (Sätze, Ziel-Wdh bzw. Ziel-Dauer, Pause) mit Link „Übung bearbeiten“ (Bibliothek).
- **„+ Übung hinzufügen“** unter der Liste: volle Breite, gestrichelter Rahmen. Öffnet Bottom Sheet:
  Suchfeld, „Zuletzt verwendet“, dann Bibliothek nach Kategorie gruppiert, Button „Neue Übung anlegen“.
  Bereits enthaltene Übungen sind markiert und nicht erneut wählbar.
- **Neue Übung anlegen** (Formular): Name, Typ (Gewicht × Wdh / Körpergewicht / Zeit), Kategorie, Ziel-Sätze (Standard aus
  Einstellungen), Ziel-Wdh bzw. Ziel-Dauer (optional), Gewichtsschritte (ab 1.1.0: Standard / Eigene in kg oder lbs / Stufen mit optional kg pro Stufe; neue Übungen: Standard), Pause (optional), Notiz.
  Speichern legt die Übung an und fügt sie direkt hinzu.
- (Bis 1.2.0: Modus „Frei“ mit temporärer Liste.)
- Unten fixiert: Primärbutton **„Training starten“** (auch bei leerem Plan möglich).
  Start legt `sessions`-Zeile an, kopiert die Liste in `session_exercises` und aktiviert die erste Übung.

### 6.2 Training – aktive Session

- AppBar: Planname bzw. „Freies Training“, rechts der **Session-Timer** (`h:mm:ss`, immer aus `startedAt` berechnet, gleich breite
  Ziffern) und Button **„Beenden“**.
- Liste der Session-Übungen. Zustände der Kachel:
  - **Offen** (`pending`): kompakt wie in 6.1, mit Fortschritt „1/3“, falls schon Sätze existieren. Drag-Handle. Tap → wird aktiv.
  - **Aktiv** (`active`, immer höchstens eine): aufgeklappt, farblich hervorgehoben (§9).
    - Kopf: Name, „Satz 2 von 3“, Fortschrittspunkte.
    - Übungsnotiz (eine Zeile, Tap → bearbeiten), Referenz „Letztes Mal (28.10.): 60 × 10, 60 × 10, 60 × 8“.
    - Erledigte Sätze dieser Session als ausgegraute Zeilen („1   60 kg × 10“). Tap → Dialog Ändern/Löschen.
    - Eingabebereich je Typ:
      - `weight_reps`: Stepper Gewicht `[−] 62,5 kg [+]` (Schritt nach den Gewichtsschritten der Übung; bei Stufen „Stufe · 45 kg“ und die Stufennummer), Stepper Wdh `[−] 10 [+]`.
      - `bodyweight`: Stepper Zusatzgewicht (Anzeige „+0 kg“, „+10 kg“, „−20 kg“), Stepper Wdh.
      - `timed`: großer Stoppuhr-Button „Start“ → läuft sichtbar → „Stopp“ übernimmt die Dauer; daneben Stepper Dauer (±5 s, `m:ss`);
        Zusatzgewicht eingeklappt hinter „Gewicht hinzufügen“.
      - Tap auf eine Zahl öffnet die Zahlentastatur zur direkten Eingabe.
    - Optionaler Vorschlags-Chip (§7.2) über den Steppern: „Vorschlag: +2,5 kg“ – Tap übernimmt, „×“ verwirft.
    - Primärbutton **„Satz speichern“** (volle Breite, mind. 56 dp). Darunter klein: „+1 Satz“, „Überspringen“,
      „Übung beenden“ (nur ab 1 Satz).
  - **Erledigt** (`done`): ausgegraut, eingeklappt, Haken, Zusammenfassung „3 Sätze, bestes 62,5 kg × 10“. Kein Drag-Handle.
    Tap → klappt auf (Sätze ansehen/ändern) mit Button „Wieder öffnen“ (→ aktiv, weitere Sätze möglich).
  - **Übersprungen** (`skipped`): wie erledigt, Label „übersprungen“.
- **Satz speichern:** Satz sofort in DB, leichte Haptik, nächster Satz vorbefüllt (§7.1), Pausentimer startet (§6.2.1).
  Ab 1.0.1 ohne Snackbar (Sätze lassen sich jederzeit bearbeiten oder löschen).
  Ist `targetSets` erreicht → Status `done`, Kachel klappt zu. Danach **keine** automatische Aktivierung der nächsten Übung
  (außer Einstellung `autoActivateNext`); stattdessen wird die nächste offene Kachel dezent markiert.
- Tap auf eine andere offene Übung macht sie aktiv; die bisher aktive wird `pending` und behält ihre Sätze.
- **Reihenfolge** während der Session: nur `pending`/`active` sind verschiebbar; `done`/`skipped` bleiben an ihrer Stelle.
- **„+ Übung hinzufügen“** unter der Liste fügt nur der Session hinzu (gleiches Bottom Sheet wie 6.1).
- **Display bleibt an**, solange eine Session aktiv ist und `keepScreenOn` gesetzt ist.
- **Wiederaufnahme:** Wird die App geschlossen oder vom System beendet, ist beim nächsten Start der Training-Tab mit der aktiven
  Session offen – exakt im vorherigen Zustand (aktive Übung, Sätze, Timer).
- **Vergessene Session:** Ist die aktive Session beim Öffnen älter als 12 h, Dialog: „Das Training vom 3.11. läuft noch.“
  Optionen: „Beenden“ (Endzeit = letzter Satz + 5 min, ohne Sätze: Startzeit) · „Fortsetzen“ · „Verwerfen“ (mit Bestätigung).

#### 6.2.1 Pausentimer

- Leiste am unteren Rand über der NavigationBar: „Pause 1:12“, Fortschrittsbalken, Buttons „−15 s“, „+15 s“, „Überspringen“.
- Dauer: `restSec` der Session-Übung → der Übung → `defaultRestSec`. Ende = `completedAt` des letzten Satzes + Dauer
  (+/− Anpassungen im State). Dadurch nach App-Neustart korrekt rekonstruierbar.
- Bei 0: Vibrationsmuster (3 × kurz, wenn `vibrationEnabled`), Leiste wechselt für 10 s auf „Pause vorbei“.
- Ab 1.0.1 auch im Hintergrund und bei gesperrtem Display: Geht die App während einer Pause in den Hintergrund, vibriert
  ein exakter Android-Alarm zum Pausenende (gleiches Muster). Keine Benachrichtigungen in v1.
- Nach „Beenden“ oder „Verwerfen“ endet die laufende Pause (keine Leiste, keine Vibration).

### 6.3 Session beenden

- „Beenden“ → wenn offene Übungen existieren: Dialog „2 Übungen sind nicht abgeschlossen. Training trotzdem beenden?“
  [Weiter trainieren] [Beenden]. Ohne jeden Satz: „Keine Sätze erfasst. Training verwerfen?“ (löscht die Session).
- Beim Beenden: `endedAt` = jetzt; Übungen ohne Sätze werden `skipped`.
- **Zusammenfassung** (Vollbild): Dauer, Übungen, Sätze, Volumen (kg), neue Rekorde (§7.7), Vergleich Volumen zum letzten Training
  mit demselben Plan (±%). Darunter:
  - Plan-Session mit geänderter Reihenfolge oder hinzugefügten Übungen: Schalter „Reihenfolge und neue Übungen in Plan „X“
    übernehmen“ (Standard aus).
  - Freie Session: Button „Als Plan speichern“ (Name eingeben).
  - Notizfeld.
  - (Bis 1.0.0 hier der Backup-Hinweis; ab 1.0.1 in Einstellungen → Daten, §6.7.)
  - Button „Fertig“ → Training-Tab im Zustand 6.1.

### 6.4 Verlauf

- Liste nach Monat gruppiert („November 2026“). Eintrag: Datum („Di, 3.11.“), Planname oder „Freies Training“, Dauer,
  Anzahl Sätze, Volumen, Rekord-Markierung falls neue Rekorde.
- Detail: Datum, Start–Ende (änderbar), Notiz; je Übung die Sätze. Satz antippen → ändern/löschen. Übung aus Session entfernen.
  Session löschen mit Bestätigung, die Datum und Planname nennt.
- Leerzustand: „Noch keine Trainings. Starte dein erstes im Tab Training.“

### 6.5 Statistik

Oben Zeitraum (SegmentedButton): 4 W · 3 M · 1 J · Alles (Standard 3 M). Darunter Tabs **Übung**, **Gesamt**, **Rekorde**.
Der Zeitraum schneidet nur die Anzeige zu; Berechnungen nutzen immer die gesamte Historie.

- **Übung:** Übungsauswahl (mit Suche, nur Übungen mit Daten). Metrik-Chips je Typ:
  - `weight_reps`: geschätztes 1RM (Standard), Maximalgewicht, Volumen pro Training
  - `bodyweight`: Max-Wdh (Standard), Gesamt-Wdh, Max-Zusatzgewicht, effektives 1RM (nur wenn Körpergewicht-Daten existieren)
  - `timed`: Max-Dauer (Standard), Gesamtdauer

  Liniendiagramm (ein Punkt pro Training), Tooltip mit Datum, Wert und Sätzen, Rekordpunkte markiert.
  Kennzahlen: Bestwert, Veränderung im Zeitraum (absolut und %), Anzahl Trainings. Tabelle der letzten 10 Trainings.
- **Gesamt:**
  1. **Kraftindex** (§7.5) als Linie in %, 100-%-Referenzlinie, Untertitel „Durchschnitt über N Übungen“.
  2. **Serie** (ab 1.0.1 eigene, hervorgehobene Karte): „N Wochen in Folge“ mit Training; ohne aktive Serie „Keine aktive
     Serie“; die längste Serie mit „nicht aktiv“, wenn sie länger ist als die aktuelle.
  3. **Körpergewicht** (ab 1.0.1 immer, ohne Schalter) mit gleicher Zeitachse wie der Kraftindex (keine Doppelachse).
  4. **Wochenvolumen** (Balken, kg, §7.6).
  5. **Trainingskalender** als Heatmap: letzte 26 Wochen, Spalten = Wochen, Zeilen = Mo–So, Intensität = Anzahl Sätze.
     Kennzahl: Ø Trainings pro Woche.
  6. **Trainingsdauer** pro Training.
  7. **Sätze pro Kategorie** im Zeitraum (horizontale Balken).
- **Rekorde:** alle Übungen mit ihren Bestwerten (§7.7) und Datum; Tap → Tab Übung mit dieser Übung.
- Leerzustände je Diagramm, z. B. „Für einen Verlauf brauchst du mindestens zwei Trainings mit dieser Übung.“

### 6.6 Körper

- Eingabekarte oben: Zahlfeld kg (eine Nachkommastelle, vorbefüllt mit dem letzten Wert), Datums-Chip „Heute“
  (Tap → DatePicker, keine Zukunft), Button „Speichern“. Existiert für das Datum ein Eintrag: „Eintrag vom 3.11. überschreiben?“
- Diagramm: Messpunkte + Linie gleitender 7-Tage-Durchschnitt (§7.8), Zeitraum wie in 6.5.
  Kennzahlen: aktuell (Ø 7 Tage), Veränderung über 30 Tage, Minimum/Maximum im Zeitraum.
- Liste der Einträge (neueste zuerst). Wisch → löschen mit „Rückgängig“, Tap → bearbeiten.

### 6.7 Einstellungen

Ab 1.2.1 eine Startseite mit je einem Eintrag (Symbol, Titel, Kurzbeschreibung) pro Bereich; jeder Bereich ist eine eigene
Seite mit deutlich abgesetzten Abschnitten: Übungen, Pläne, Training, Benachrichtigungen, Automatische Buchung
(Buchungsseite, später Buchungsdetails), Darstellung, Daten, Über. Ein fälliges Backup zeigt die gelbe Karte auch oben auf
der Startseite (nur wenn es Trainings gibt).

- **Übungen:** Liste mit Suche und Kategorie-Filter; anlegen, bearbeiten, archivieren bzw. löschen (§5); Archiv mit „Wiederherstellen“.
- **Pläne:** Liste mit Reorder (= Reihenfolge der Chips) und Trainingstagen; Tippen öffnet die **Plan-Seite** (ab 1.2.1):
  Name ändern, Schalter „Aktiv“, Abschnitt „Trainingstage“ (Wochentag + Uhrzeit), „Duplizieren“, „Löschen“.
- **Training:** Standard-Satzanzahl, Standard-Pause (s), Pausentimer an/aus, Vibration an/aus, Display anlassen,
  Nächste Übung automatisch aktivieren.
- **Darstellung:** System / Hell / Dunkel.
- **Daten:** „CSV exportieren“, „Backup erstellen“, „Backup wiederherstellen“, „Letztes Backup: 3.11.2026, 18:20“,
  Backup-Erinnerung (Tage, 0 = aus). Ab 1.0.1 steht hier unter „Daten“ der gelbe Hinweis „Letztes Backup vor … Tagen“
  mit „Backup erstellen“, sobald die Erinnerung fällig ist.
- **Über:** „Nach Updates suchen“ (ab 1.2.1, Antippen sucht sofort; neue Version → Hinweis und „Zur Release-Seite“, die
  der Nutzer im Browser liest und selbst entscheidet), App-Version, Build-Nummer, Datenbank-Schemaversion, Lizenzen.
- **Nur im Dev-Build** (`de.gymlog.app.dev`): „Demo-Daten erzeugen“ und „Alle Daten löschen“ (mit Bestätigung).

## 7. Logik und Formeln (Domain, reines Dart, mit Tabellentests)

Arbeitssätze = Sätze mit `isWarmup == false`. Alle Berechnungen nutzen nur Arbeitssätze.

### 7.1 Vorbefüllung für Satz n einer Session-Übung
1. Existiert Satz n−1 in dieser Session → dessen Werte.
2. Sonst die letzte abgeschlossene Session mit dieser Übung → deren Satz n, falls nicht vorhanden deren letzter Satz.
3. Sonst: Wdh = `targetReps`, Dauer = `targetDurationSec`, Gewicht leer (`weight_reps`) bzw. 0 (`bodyweight`).

### 7.2 Steigerungsvorschlag (nur für Satz 1)
- Bedingung: Ziel (`targetReps` bzw. `targetDurationSec`) ist gesetzt, und in der letzten Session mit dieser Übung wurden
  mindestens `targetSets` Arbeitssätze erfasst, die alle das Ziel erreicht haben.
- Vorschlag: `weight_reps` → ein Gewichtsschritt mehr (nächste Scheibe bzw. Stufe, ab 1.1.0) · `bodyweight` → mit Zusatzgewicht > 0: ein Schritt mehr, sonst Wdh + 1 ·
  `timed` → Dauer + 5 s.
- Der Vorschlag wird nur angeboten (Chip), nie automatisch übernommen.

### 7.3 Geschätztes 1RM (Epley)
- `e1RM(w, r) = w` für r = 1, sonst `w × (1 + r / 30)`. Für r = 0 oder w ≤ 0 nicht definiert.
- **Effektive Last** für `bodyweight`: `L = KG + Zusatzgewicht`. KG = Körpergewicht-Eintrag mit dem geringsten zeitlichen Abstand
  zum Session-Datum (davor oder danach). Ohne jeden Körpergewicht-Eintrag nicht berechenbar.

### 7.4 Leistungswert P(Übung, Session)
- `weight_reps`: max e1RM über die Sätze.
- `bodyweight`: max e1RM mit effektiver Last, falls es überhaupt Körpergewicht-Einträge gibt; sonst max Wdh.
  (Die Wahl gilt einheitlich für die gesamte Historie und wird bei jeder Berechnung neu bestimmt.)
- `timed`: max Dauer.

### 7.5 Kraftindex
- Berücksichtigt: Übungen mit `includeInStrengthIndex`.
- Baseline `B_e` = P der ersten Session mit Übung e (gesamte Historie).
- Für jede ISO-Woche w ab der ersten Trainingswoche:
  `I_e(w)` = bester P_e in Woche w / B_e. Ohne Wert in w: letzter bekannter `I_e` (höchstens 8 Wochen fortgeschrieben,
  danach fällt e aus der Mittelung, bis es wieder trainiert wird). Vor der ersten Session von e: nicht enthalten.
- `Kraftindex(w)` = Mittelwert der enthaltenen `I_e(w)` × 100 %. N = Anzahl enthaltener Übungen in w.

### 7.6 Volumen
Σ (Gewicht × Wdh) über Arbeitssätze von `weight_reps`-Übungen. Pro Training und pro ISO-Woche.

### 7.7 Rekorde
- `weight_reps`: höchstes e1RM, höchstes Gewicht.
- `bodyweight`: meiste Wdh in einem Satz, höchstes Zusatzgewicht.
- `timed`: längste Dauer.
- **Live-Erkennung** beim Speichern eines Satzes: Rekord, wenn der Wert strikt größer ist als alle früheren Arbeitssätze dieser
  Übung (inklusive früherer Sätze derselben Session). In der allerersten Session einer Übung werden keine Rekorde gemeldet.
  Anzeige: kurzes rotes Aufleuchten der Kachel, Rekord-Label am Satz, mittlere Haptik.

### 7.8 Gleitender Durchschnitt Körpergewicht
Für jeden Eintrag mit Datum d: Mittelwert aller Einträge im Intervall [d − 6 Tage, d].

## 8. Export, Backup, Import

### 8.1 CSV-Export
ZIP `gymlog-export-YYYY-MM-DD.zip` mit vier Dateien. UTF-8 ohne BOM, Komma als Trenner, Punkt als Dezimalzeichen,
Kopfzeile, Quoting nach RFC 4180, leeres Feld für null, Zeitpunkte ISO 8601 mit Offset (lokal).

- `sets.csv`: `session_id, session_date, session_started_at, plan_name, exercise_id, exercise_name, exercise_type, category,
  exercise_position, set_index, weight_kg, reps, duration_s, is_warmup, e1rm_kg, completed_at, weight_unit` (ab 1.1.0:
  `kg` oder `level`, wenn `weight_kg` eine Stufennummer enthält)
- `sessions.csv`: `session_id, plan_name, started_at, ended_at, duration_s, n_exercises, n_sets, volume_kg, notes`
- `body_weight.csv`: `date, weight_kg`
- `exercises.csv`: `exercise_id, name, type, category, increment_kg, include_in_strength_index, archived, notes` (ab 1.1.0
  zusätzlich `step_mode, increment_lbs, level_kg`)

Nur abgeschlossene Sessions. Ausgabe über das Teilen-Menü; zusätzlich „Speichern unter …“ über den System-Dateidialog.

### 8.2 JSON-Backup
Datei `gymlog-backup-YYYY-MM-DD-HHmm.json`:
```json
{
  "format": "gymlog-backup",
  "formatVersion": 1,
  "schemaVersion": 1,
  "appVersion": "1.0.0+12",
  "exportedAt": "2026-11-03T18:20:00+01:00",
  "data": {
    "exercises": [], "plans": [], "planExercises": [], "sessions": [],
    "sessionExercises": [], "sets": [], "bodyWeights": [], "settings": {}
  }
}
```
Alle Spalten aller Tabellen, IDs bleiben erhalten. Nach erfolgreichem Teilen/Speichern `lastBackupAt` setzen
(CSV-Export zählt nicht als Backup).
Formatversionen: 2 ab M9 (Gruppen), 3 ab 1.1.0 (Gewichtsschritte). Ältere Formate werden weiter gelesen; Übungen aus
Backups vor 1.1.0 bekommen dieselben Gewichtsschritte wie bei der Datenbank-Migration (Geräte/Kabel der Bibliothek
„Standard“, Bizeps-/Trizeps-Kabel „Stufen × 4,5 kg“).

### 8.3 Import
1. Datei wählen → validieren (`format`, `formatVersion` ≤ unterstützt, Pflichtfelder, referentielle Integrität).
2. Vorschau: Anzahl Trainings, Zeitraum, Anzahl Körpergewicht-Einträge.
3. Bestätigung: „Alle aktuellen Daten werden ersetzt.“
4. Vorher automatisch Sicherheitskopie des aktuellen Stands als JSON in das App-Dokumentenverzeichnis (die letzten 3 behalten).
5. Import in **einer** Transaktion; bei Fehler Rollback und verständliche Meldung.
- Während einer aktiven Session ist der Import gesperrt.
- Pflicht-Test: Export → Import → Datenbankinhalt identisch.

## 9. Design

**Leitidee: Hantelscheiben und Eisen.** Die Farbsemantik folgt den Farben von Wettkampf-Hantelscheiben – im Studio vertraut und
selbsterklärend. Flächen erinnern an Stahl und Gummiboden, nicht an eine App-Vorlage.

| Name | Hex | Rolle |
|---|---|---|
| Eisen | `#1B1E21` | Hintergrund dunkel |
| Eisen hell | `#262A2E` | Flächen/Karten dunkel |
| Stahl | `#E9ECEF` | Hintergrund hell |
| Scheibe Blau | `#1F5FBF` | Primär: aktive Übung, Hauptaktionen |
| Scheibe Rot | `#C8102E` | Rekorde, destruktive Aktionen |
| Scheibe Gelb | `#F2B705` | Pausentimer, Hinweise |
| Scheibe Grün | `#2E8B57` | Erledigt, „Pause vorbei“ |

- `ColorScheme` für hell und dunkel von Hand definieren (nicht aus einer Seed-Farbe). Für Text und Icons auf dunklem Grund
  hellere Töne der Scheibenfarben ableiten; Kontrast mindestens 4,5:1 (Text) bzw. 3:1 (große Ziffern, Icons) prüfen.
- **Schrift:** Barlow (OFL, Google Fonts) für die gesamte UI; Barlow Semi Condensed für große Zahlen (Gewicht, Wdh, Timer).
  Dateien unter `assets/fonts/` bündeln, Lizenz beilegen. Timer und Stepper-Zahlen mit Tabellenziffern (`FontFeature.tabularFigures()`).
  Unterstützt die Schrift das nicht, für Ziffern eine Schrift mit `tnum` wählen und das in PROGRESS.md notieren – Ziffern dürfen
  beim Hochzählen nicht springen.
- **Zahlen sind die Hauptsache:** Gewicht, Wdh und Timer ≥ 32 sp, Beschriftungen klein und ruhig.
- **Daumenzone:** Primäraktionen in der unteren Bildschirmhälfte.
- **Zustand nie nur über Farbe:** aktiv = blaue 4-dp-Kante links + erhöhte Fläche; erledigt = reduzierte Deckkraft + Haken;
  Rekord = rot + Label.
- **Bewegung nur als Antwort auf Aktionen** (Aufklappen, Satz gespeichert, Kachel erledigt). Der einzige hervorgehobene Moment ist
  das Rekord-Aufleuchten. Keine Verläufe, keine dekorativen Schatten. Eckenradius: Karten 12 dp, Buttons 12 dp, Chips 8 dp.
- **Texte:** Satzanfang groß, aktive Verben, eine Aktion heißt überall gleich.
- **Snackbars (ab 1.0.1):** keine Bestätigungen. Nur Fehler, Hinweise ohne sichtbares Ergebnis und Löschen mit „Rückgängig“
  (Körpergewicht, Training im Verlauf, Übung aus der Plan-/freien Liste); sie verschwinden nach 5 s von selbst.
  Fehlermeldungen sagen, was passiert ist und was zu tun ist. Leerzustände laden zur nächsten Aktion ein.
- Systemschriftgröße bis Faktor 1,3 ohne Layoutbruch.

## 10. Qualität und Tests

- `./scripts/check.sh` grün: Formatierung, `flutter analyze` ohne Hinweise, alle Tests.
- **Unit-Tests (domain):** e1RM, effektive Last, Leistungswert, Kraftindex inkl. Fortschreiben und 8-Wochen-Grenze,
  Volumen, Rekorde inkl. „erste Session“, Vorbefüllung, Steigerungsvorschlag, gleitender Durchschnitt, ISO-Wochen über
  Jahreswechsel, CSV-Escaping, JSON-Roundtrip.
- **Repository-Tests** mit In-Memory-drift: höchstens eine aktive Session, Archivieren statt Löschen, Kaskaden.
- **Migrationstests** ab Schema 2.
- **Widget-Tests:** Session-Ablauf (starten → 3 Sätze → Übung erledigt → beenden → Zusammenfassung), Reorder-Regeln
  (erledigte nicht verschiebbar), Rückgängig, Körpergewicht speichern/überschreiben.
- Performance mit Demo-Daten (≥ 1 Jahr, 4 Trainings/Woche): flüssiges Scrollen, Statistik-Tab öffnet ohne spürbare Verzögerung.

## 11. Meilensteine

Jeder Meilenstein endet mit grünem `check.sh`, Commit, aktualisierter `PROGRESS.md` (inkl. manueller Testliste) und Stopp.

- **M0 Grundgerüst:** `flutter create --project-name gymlog --org de.gymlog --platforms android .` im bestehenden Ordner, ohne
  vorhandene Dateien (README.md, CLAUDE.md, docs/, docker/, scripts/, .claude/, .devcontainer/, .gitignore, .gitattributes) zu
  überschreiben; `.gitignore` ergänzen. `namespace`/`applicationId` `de.gymlog.app`, Debug-Suffix, App-Namen, Release-Signatur
  (§3), Hochformat, Permissions, Lints, Ordnerstruktur (§4), Pakete (§2), Theme + Schriften (§9), Shell mit vier leeren Tabs
  und Einstellungs-Route, Clock-Provider, `strings_de.dart`. Akzeptanz: `flutter build apk --debug` funktioniert, die DEV-App
  zeigt die Navigation im richtigen Design.
- **M1 Datenbank:** Tabellen (§5), DAOs, Repositories mit Streams, Settings-Zeile, Schema-Dump-Setup, Repository-Tests,
  Demo-Daten-Generator (16 Wochen, 2 Pläne + freie Trainings, ca. 12 Übungen aller Typen, Progression mit Rauschen, einzelne
  ausgelassene Wochen, Körpergewicht 3–5 ×/Woche mit leichtem Trend) und Dev-Einstellungen aus §6.7.
- **M2 Übungen und Pläne:** Einstellungen → Übungen/Pläne; Training-Tab ohne Session (§6.1) komplett.
- **M3 Session-Kern:** §6.2 ohne 6.2.1, ohne Vorschlags-Chip und ohne Rekorde; §6.3 ohne Rekorde und Backup-Hinweis;
  Vorbefüllung (§7.1), „Letztes Mal“, Stoppuhr, Rückgängig, Wiederaufnahme, vergessene Session, Plan übernehmen / als Plan speichern.
- **M4 Komfort im Studio:** Pausentimer (§6.2.1), Display anlassen, Steigerungsvorschlag (§7.2), Rekord-Erkennung live und in der
  Zusammenfassung (§7.7), Übungsnotiz in der Kachel.
- **M5 Verlauf** (§6.4).
- **M6 Körper** (§6.6).
- **M7 Statistik** (§6.5, §7.3–7.6).
- **M8 Daten und Einstellungen:** Export/Backup/Import (§8), Backup-Hinweis (§6.3), restliche Einstellungen (§6.7).
- **M9 Feinschliff, Version 1.0.0:** Leerzustände, hell/dunkel, Schriftskalierung, Launcher-Icons (DEV unterscheidbar),
  Performance-Check mit Demo-Daten, Gesamt-Testliste in PROGRESS.md.

## 12. Später (nicht ohne ausdrücklichen Auftrag umsetzen)

Scheibenrechner · Aufwärmsätze in der UI · Training nachtragen · Pausentimer-Benachrichtigung im Hintergrund ·
Homescreen-Widget fürs Körpergewicht · Supersätze · Zielgewicht-Linie im Körper-Tab · automatisches Backup in einen gewählten Ordner.
