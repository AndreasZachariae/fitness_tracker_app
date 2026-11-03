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
- [ ] M8 Daten und Einstellungen
- [ ] M9 Feinschliff, Version 1.0.0

## Annahmen

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
- Unterscheidbares DEV-Launcher-Icon folgt laut §11 in M9; bis dahin unterscheidet der Name „GymLog DEV“.
- Beim App-Start zeigt das Startbild-Theme der Vorlage (`LaunchTheme`) kurz weiße Statusleisten-Symbole auf hellem Grund,
  bis Flutter übernimmt. Wird in M9 (Feinschliff) mit dem Startbild angepasst.
- **USB-Debugging im Container:** `/dev/bus/usb` als Bind-Mount plus `device_cgroup_rules: c 189:* rmw` statt `devices:`,
  weil Android sich bei jedem Einstecken mit neuer Gerätenummer anmeldet. Zugriffsrechte über eine udev-Regel auf dem Host
  (`scripts/setup-usb-host.sh`, Gruppe = Host-GID = Container-GID).

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
  geändert werden. Generierte Helfer unter `test/data/db/migrations/generated/` sind von der Analyse ausgenommen.
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
- `scripts/dev-install.sh` weckt das Display nicht: Bei gesperrtem Handy zeigen Screenshots den Sperrbildschirm und sind
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
| `flutter_localizations` (SDK) | Deutsche Material-Texte (DatePicker, Tooltips wie „Zurück“) | Für Locale `de_DE` in `MaterialApp` nötig, Teil des Flutter-SDK | M0 |

## Manuelle Tests am Handy

<!-- Pro Meilenstein eine kurze Checkliste, was der Mensch in der DEV-App ausprobieren soll. -->

### M0 Grundgerüst
Am Pixel 4a (5G) per USB geprüft (`dev-install.sh` + Screenshot): Training-Tab im hellen Design, Barlow, Statusleiste lesbar.
Handy verbinden: per USB `./scripts/connect-usb.sh` (einmalig vorher `./scripts/setup-usb-host.sh` auf dem Host),
per WLAN `./scripts/connect-phone.sh`; danach `./scripts/dev-install.sh`.
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
Vorher: Handy entsperren, dann `./scripts/connect-usb.sh` und `./scripts/dev-install.sh`.
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
Vorher: Handy entsperren, `./scripts/connect-usb.sh`, `./scripts/dev-install.sh`, in den Einstellungen „Demo-Daten erzeugen“.
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
Vorher: `./scripts/dev-install.sh`, in den Einstellungen „Demo-Daten erzeugen“, Plan „Oberkörper“ wählen, „Training starten“.
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

