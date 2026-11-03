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
- [ ] M4 Komfort im Studio
- [ ] M5 Verlauf
- [ ] M6 Körper
- [ ] M7 Statistik
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

