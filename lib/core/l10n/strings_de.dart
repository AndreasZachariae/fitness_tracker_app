import '../../domain/models/enums.dart';
import '../../domain/records.dart';
import '../../domain/statistics.dart';

/// All user-facing German texts of the app.
///
/// UI code never contains string literals for visible texts; it references
/// these constants instead.
abstract final class S {
  static const appName = 'GymLog';

  // Tabs
  static const tabTraining = 'Training';
  static const tabHistory = 'Verlauf';
  static const tabStats = 'Statistik';
  static const tabBody = 'Körper';

  // Settings
  static const settings = 'Einstellungen';
  static const openSettings = 'Einstellungen öffnen';

  // Placeholders until the tabs are implemented
  static const historyEmpty =
      'Noch keine Trainings. Starte dein erstes im Tab Training.';
  static const settingsExercises = 'Übungen';
  static const settingsExercisesSubtitle = 'Bibliothek, Archiv';
  static const settingsPlans = 'Pläne';
  static const settingsPlansSubtitle = 'Reihenfolge, umbenennen, duplizieren';

  // Settings – dev build only
  static const devSection = 'Entwicklung (nur GymLog DEV)';
  static const devDemoData = 'Demo-Daten erzeugen';
  static const devDemoDataSubtitle =
      'Ersetzt alle Daten durch 16 Wochen Beispieltraining.';
  static const devDemoDataConfirmTitle = 'Demo-Daten erzeugen?';
  static const devDemoDataConfirmBody =
      'Alle Daten in GymLog DEV werden durch Beispieldaten ersetzt.';
  static const devDemoDataConfirm = 'Erzeugen';
  static String devDemoDataDone(String sessions, String sets, String weights) =>
      'Demo-Daten erzeugt: $sessions Trainings, $sets Sätze, '
      '$weights Körpergewicht-Einträge.';
  static const devDemoDataFailed =
      'Demo-Daten konnten nicht erzeugt werden. Deine bisherigen Daten sind '
      'unverändert.';
  static const devDeleteAll = 'Alle Daten löschen';
  static const devDeleteAllSubtitle =
      'Löscht Trainings, Pläne, Übungen und Körpergewicht.';
  static const devDeleteAllConfirmTitle = 'Alle Daten löschen?';
  static const devDeleteAllConfirmBody =
      'Alle Trainings, Pläne, Übungen und Körpergewicht-Einträge in '
      'GymLog DEV werden gelöscht. Das lässt sich nicht rückgängig machen.';
  static const devDeleteAllConfirm = 'Löschen';
  static const devDeleteAllDone = 'Alle Daten gelöscht.';
  static const devDeleteAllFailed =
      'Löschen fehlgeschlagen. Deine Daten sind unverändert.';

  // Common actions
  static const cancel = 'Abbrechen';
  static const save = 'Speichern';
  static const create = 'Anlegen';
  static const undo = 'Rückgängig';
  static const rename = 'Umbenennen';
  static const duplicate = 'Duplizieren';
  static const delete = 'Löschen';
  static const archive = 'Archivieren';
  static const restore = 'Wiederherstellen';
  static const search = 'Suchen';
  static const decrease = 'Weniger';
  static const increase = 'Mehr';
  static const dragToReorder = 'Ziehen zum Verschieben';
  static const moreActions = 'Weitere Aktionen';

  // Exercise types and categories
  static String exerciseType(ExerciseType type) => switch (type) {
    ExerciseType.weightReps => 'Gewicht × Wdh',
    ExerciseType.bodyweight => 'Körpergewicht',
    ExerciseType.timed => 'Zeit',
  };

  static String category(ExerciseCategory? category) => switch (category) {
    ExerciseCategory.chest => 'Brust',
    ExerciseCategory.back => 'Rücken',
    ExerciseCategory.legs => 'Beine',
    ExerciseCategory.shoulders => 'Schultern',
    ExerciseCategory.arms => 'Arme',
    ExerciseCategory.core => 'Rumpf',
    ExerciseCategory.fullBody => 'Ganzkörper',
    ExerciseCategory.other => 'Sonstiges',
    null => 'Ohne Kategorie',
  };

  // Formats
  static String sets(int n) => n == 1 ? '1 Satz' : '$n Sätze';
  static const repsUnit = 'Wdh';
  static const secondsUnit = 's';
  static const minutesUnit = 'min';
  static String lastTime(String summary) => 'Zuletzt: $summary';

  // Exercises (settings)
  static const exercisesTitle = 'Übungen';
  static const exercisesEmpty =
      'Noch keine Übungen. Lege deine erste an oder füge oben die '
      'Standardübungen hinzu.';
  static const addLibrary = 'Standardübungen hinzufügen';
  static String addLibraryBody(int n) =>
      '${n == 1 ? '1 Übung' : '$n Übungen'} aus der mitgelieferten Bibliothek '
      'fehlen noch. Deine eigenen Übungen bleiben unverändert.';
  static const addLibraryConfirm = 'Hinzufügen';
  static const libraryComplete =
      'Alle Standardübungen sind schon vorhanden (auch archivierte zählen).';
  static const exercisesNoMatch = 'Keine Übung passt zur Suche.';
  static const allCategories = 'Alle';
  static const newExercise = 'Neue Übung';
  static const archiveTitle = 'Archiv';
  static const archiveEmpty = 'Keine archivierten Übungen.';
  static const openArchive = 'Archiv öffnen';
  static String deleteExerciseTitle(String name) => '„$name“ löschen?';
  static String archiveExerciseTitle(String name) => '„$name“ archivieren?';
  static const deleteExerciseBody = 'Die Übung wurde noch nie trainiert.';
  static const archiveExerciseBody =
      'Die Übung kommt in deinen Trainings vor. Sie wird archiviert, der '
      'Verlauf bleibt erhalten. Im Archiv kannst du sie wiederherstellen.';
  static String removedFromPlans(int n) => n == 0
      ? ''
      : n == 1
      ? ' Sie wird aus 1 Plan entfernt.'
      : ' Sie wird aus $n Plänen entfernt.';

  // Exercise form
  static const editExercise = 'Übung bearbeiten';
  static const fieldName = 'Name';
  static const fieldType = 'Typ';
  static const fieldCategory = 'Kategorie';
  static const fieldTargetSets = 'Ziel-Sätze';
  static const fieldTargetReps = 'Ziel-Wdh';
  static const fieldTargetDuration = 'Ziel-Dauer';
  static const level = 'Stufe';
  static const enterLevel = 'Stufe eingeben';
  static const plusOneLevel = '+1 Stufe';
  static const levelReps = 'Stufen × Wdh';
  static const fieldRest = 'Pause in Sekunden';
  static String fieldRestHint(int defaultSec) => 'Standard: $defaultSec s';
  static const fieldNotes = 'Notiz';
  static const fieldNotesHint = 'z. B. Sitzhöhe 4, Griff eng';
  static const fieldStrengthIndex = 'Im Kraftindex berücksichtigen';
  static const optional = 'optional';
  static const noTarget = 'ohne Ziel';
  static const typeLocked =
      'Der Typ lässt sich nicht mehr ändern, weil es schon Trainings mit '
      'dieser Übung gibt.';
  static const stepChangeNeedsLevelKg =
      'Die Sätze dieser Übung sind als Stufen ohne kg gespeichert. Gib „kg pro '
      'Stufe“ an, dann rechnet GymLog sie in kg um.';
  static const errorNameRequired = 'Gib einen Namen ein.';
  static const errorNameTooLong = 'Höchstens 60 Zeichen.';
  static const errorExerciseNameTaken =
      'Es gibt schon eine Übung mit diesem Namen (auch im Archiv).';
  static const errorPlanNameTaken =
      'Es gibt schon einen Plan mit diesem Namen.';
  static const errorIncrement = 'Gib eine Zahl größer als 0 ein, z. B. 2,5.';
  static const fieldStep = 'Gewichtsschritte';
  static const stepStandard = 'Standard';
  static const stepCustom = 'Eigene';
  static const stepLevels = 'Stufen';
  static String stepStandardHint(String step) =>
      'Wie in den Einstellungen: $step pro Schritt.';
  static const stepLbsHint =
      'Für Geräte mit lbs-Scheiben: + und − springen zur nächsten Scheibe, '
      'angezeigt wird der aufgedruckte kg-Wert.';
  static const fieldStepValue = 'Schritt';
  static const fieldLevelKg = 'kg pro Stufe (optional)';
  static const fieldLevelKgHint = 'z. B. 4,5';
  static const stepLevelsHint =
      'Für Geräte mit nummerierten Stufen. Mit kg pro Stufe zeigt GymLog '
      '„Stufe 10 (45 kg)“ und rechnet in kg; ohne zählt die Übung nicht zum '
      'Wochenvolumen.';
  static const errorStepLbs = 'Gib eine Zahl größer als 0 ein, z. B. 15.';
  static const errorLevelKg =
      'Gib eine Zahl größer als 0 ein oder lass es leer.';
  static const convertToKgTitle = 'Sätze in kg umrechnen?';
  static String convertToKgBody(String kg) =>
      'Die bisherigen Sätze dieser Übung sind als Stufen gespeichert. Sie '
      'werden mit $kg pro Stufe in kg umgerechnet.';
  static const convertToLevelsTitle = 'Sätze in Stufen umrechnen?';
  static String convertToLevelsBody(String kg) =>
      'Die bisherigen Sätze dieser Übung sind in kg gespeichert. Sie werden '
      'mit $kg pro Stufe in Stufen umgerechnet.';
  static const convert = 'Umrechnen';
  static const errorRest = 'Gib eine ganze Zahl von 0 bis 3600 ein.';
  static const errorPositiveNumber = 'Gib eine ganze Zahl größer als 0 ein.';

  // Plans
  static const plansTitle = 'Pläne';
  static const plansEmpty = 'Noch keine Pläne. Lege deinen ersten an.';
  static const newPlan = 'Neuer Plan';
  static const addPlanChip = 'Plan';
  static const renamePlan = 'Plan umbenennen';
  static const duplicatePlan = 'Plan duplizieren';
  static String copyName(String name) => '$name (Kopie)';
  static String exerciseCount(int n) => n == 1 ? '1 Übung' : '$n Übungen';
  static String deletePlanTitle(String name) => 'Plan „$name“ löschen?';
  static const deletePlanBody =
      'Der Plan und seine Übungsliste werden gelöscht. Deine Trainings im '
      'Verlauf bleiben erhalten.';

  // Training tab (no active session)
  static const freeTraining = 'Frei';
  static const freeTrainingTitle = 'Freies Training';
  static const freeEmpty = 'Füge Übungen hinzu oder starte direkt.';
  static const planEmpty = 'Dieser Plan hat noch keine Übungen.';
  static const sessionEmpty =
      'Noch keine Übungen in diesem Training. Füge unten eine hinzu.';
  static const sessionDetailEmpty =
      'Dieses Training enthält keine Übungen mehr.';
  static const noPlansHint = 'Lege mit „+ Plan“ deinen ersten Plan an.';
  static const addExercise = 'Übung hinzufügen';
  static const startTraining = 'Training starten';
  static String removedFromList(String name) => '„$name“ entfernt.';
  static const remove = 'Entfernen';

  // Plan entry sheet
  static const editInPlan = 'Im Plan bearbeiten';
  static const editInFreeList = 'Im Training bearbeiten';
  static const fieldSets = 'Sätze';
  static const fieldRestShort = 'Pause';
  static String restDefault(String value) => 'Standard ($value)';
  static const resetToDefault = 'Standard verwenden';

  // Exercise picker
  static const pickerTitle = 'Übung hinzufügen';
  static const pickerSearchHint = 'Übung suchen';
  static const recentlyUsed = 'Zuletzt verwendet';
  static const alreadyAdded = 'Bereits enthalten';
  static const createExercise = 'Neue Übung anlegen';
  static const pickerEmpty =
      'Noch keine Übungen in der Bibliothek. Lege eine an oder füge in den '
      'Einstellungen bei „Übungen“ die Standardübungen hinzu.';

  // Active session (SPEC §6.2)
  static const finishTraining = 'Beenden';
  static String setOf(int n, int total) => 'Satz $n von $total';
  static String progress(int n, int total) => '$n/$total';
  static String lastTimeOn(String date, String summary) =>
      'Letztes Mal ($date): $summary';
  static const saveSet = 'Satz speichern';
  static const addOneSet = '+1 Satz';
  static const skip = 'Überspringen';
  static const finishExercise = 'Übung beenden';
  static const reopen = 'Wieder öffnen';
  static const skippedLabel = 'übersprungen';
  static String doneSummary(int sets, String best) =>
      '${S.sets(sets)}, bestes $best';
  static const nextUp = 'Als Nächstes';
  static const weight = 'Gewicht';
  static const addedWeight = 'Zusatzgewicht';
  static const reps = 'Wiederholungen';
  static const duration = 'Dauer';
  static const addWeight = 'Gewicht hinzufügen';
  static const stopwatchStart = 'Start';
  static const stopwatchStop = 'Stopp';
  static const enterWeight = 'Gewicht in kg';
  static const enterReps = 'Wiederholungen';
  static const enterDuration = 'Dauer (Sekunden oder m:ss)';
  static const errorNumber = 'Gib eine gültige Zahl ein.';
  static String editSet(int n) => 'Satz $n ändern';
  static const ok = 'OK';
  static String openExercisesTitle(int n) => n == 1
      ? '1 Übung ist nicht abgeschlossen. Training trotzdem beenden?'
      : '$n Übungen sind nicht abgeschlossen. Training trotzdem beenden?';
  static const discardNoSetsTitle = 'Keine Sätze erfasst. Training verwerfen?';
  static const keepTraining = 'Weiter trainieren';
  static const discard = 'Verwerfen';
  static String trainingRunning(String time) => 'Training läuft – $time';
  static const trainingRunningA11y = 'Laufendes Training öffnen';

  // Rest timer (SPEC §6.2.1)
  static const rest = 'Pause';
  static const restMinus = '−15 s';
  static const restPlus = '+15 s';
  static const restSkip = 'Überspringen';
  static const restOver = 'Pause vorbei';

  // Progression suggestion (SPEC §7.2)
  static String suggestion(String delta) => 'Vorschlag: $delta';
  static const plusOneRep = '+1 Wdh';
  static const dismissSuggestion = 'Vorschlag verwerfen';

  // Records (SPEC §7.7)
  static const record = 'Rekord';
  static const newRecords = 'Neue Rekorde';
  static String recordKind(RecordKind kind) => switch (kind) {
    RecordKind.estimatedOneRepMax => 'Geschätztes 1RM',
    RecordKind.weight => 'Höchstes Gewicht',
    RecordKind.reps => 'Meiste Wdh',
    RecordKind.addedWeight => 'Höchstes Zusatzgewicht',
    RecordKind.duration => 'Längste Dauer',
  };

  // Exercise note in the active tile
  static const addNote = 'Notiz hinzufügen';
  static const editNote = 'Notiz zur Übung';

  // Forgotten session
  static String forgottenTitle(String date) =>
      'Das Training vom $date läuft noch.';
  static const forgottenBody =
      '„Beenden“ setzt das Ende auf 5 Minuten nach dem letzten Satz.';
  static const resume = 'Fortsetzen';
  static const discardConfirmTitle = 'Training wirklich verwerfen?';
  static const discardConfirmBody =
      'Das Training und alle seine Sätze werden gelöscht.';

  // Summary (SPEC §6.3)
  static const summaryTitle = 'Training beendet';
  static const statDuration = 'Dauer';
  static const statExercises = 'Übungen';
  static const statSets = 'Sätze';
  static const statVolume = 'Volumen';
  static String compareLast(String percent) => '$percent zum letzten Mal';
  static String adoptIntoPlan(String plan) =>
      'Reihenfolge, Supersets und neue Übungen in Plan „$plan“ übernehmen';
  static const saveAsPlan = 'Als Plan speichern';
  static String savedAsPlan(String name) => 'Als Plan „$name“ gespeichert.';
  static const summaryNotesHint = 'Wie lief das Training?';
  static const finished = 'Fertig';

  // History (SPEC §6.4)
  static String historyEntry(String duration, int sets, String volume) =>
      '$duration · ${S.sets(sets)} · $volume';
  static const recordsInSession = 'Neue Rekorde in diesem Training';
  static const editTimes = 'Zeiten ändern';
  static const start = 'Start';
  static const end = 'Ende';
  static const errorEndBeforeStart = 'Das Ende muss nach dem Start liegen.';
  static const errorEndInFuture = 'Das Ende darf nicht in der Zukunft liegen.';
  static const deleteSession = 'Training löschen';
  static String deleteSessionTitle(String date, String plan) =>
      'Training vom $date („$plan“) löschen?';
  static const deleteSessionBody =
      'Alle Übungen und Sätze dieses Trainings werden gelöscht. Das lässt '
      'sich nicht rückgängig machen.';
  static const sessionDeleted = 'Training gelöscht.';
  static const removeFromSession = 'Aus Training entfernen';
  static String removeFromSessionTitle(String name) =>
      '„$name“ aus diesem Training entfernen?';
  static const removeFromSessionBody =
      'Die Übung und ihre Sätze werden aus diesem Training gelöscht.';
  static const noSetsRecorded = 'Keine Sätze erfasst.';

  // Body weight (SPEC §6.6)
  static const today = 'Heute';
  static const weightKgLabel = 'Gewicht in kg';
  static String overwriteEntry(String date) =>
      'Eintrag vom $date überschreiben?';
  static const overwrite = 'Überschreiben';
  static const errorBodyWeight = 'Gib ein Gewicht zwischen 20 und 400 kg ein.';
  static const bodyEntries = 'Einträge';
  static const bodyCurrent = 'Aktuell (Ø 7 Tage)';
  static const bodyChange30 = '30 Tage';
  static const bodyMinMax = 'Min / Max';
  static const bodyChartEmpty =
      'Für einen Verlauf brauchst du mindestens zwei Einträge im Zeitraum.';
  static const bodyFirstHint =
      'Trage dein Gewicht ein, um den Verlauf zu sehen.';
  static String entryDeleted(String date) => 'Eintrag vom $date gelöscht.';
  static const editEntry = 'Eintrag ändern';
  static const average7 = 'Ø 7 Tage';
  static const measurement = 'Messung';

  // Periods (SPEC §6.5)
  static const period4w = '4 W';
  static const period3m = '3 M';
  static const period1y = '1 J';
  static const periodAll = 'Alles';

  // Statistics (SPEC §6.5)
  static const statsTabExercise = 'Übung';
  static const statsTabOverall = 'Gesamt';
  static const statsTabRecords = 'Rekorde';
  static const statsNoData =
      'Noch keine Daten. Sobald du trainierst, siehst du hier deine Fortschritte.';
  static const statsSeriesEmpty =
      'Für einen Verlauf brauchst du mindestens zwei Trainings mit dieser Übung '
      'im Zeitraum.';
  static const chooseExercise = 'Übung wählen';
  static String metric(ExerciseMetric m) => switch (m) {
    ExerciseMetric.estimatedOneRepMax => 'Geschätztes 1RM',
    ExerciseMetric.maxWeight => 'Maximalgewicht',
    ExerciseMetric.volume => 'Volumen',
    ExerciseMetric.maxReps => 'Max. Wdh',
    ExerciseMetric.totalReps => 'Gesamt-Wdh',
    ExerciseMetric.maxAddedWeight => 'Max. Zusatzgewicht',
    ExerciseMetric.effectiveOneRepMax => 'Effektives 1RM',
    ExerciseMetric.maxDuration => 'Max. Dauer',
    ExerciseMetric.totalDuration => 'Gesamtdauer',
  };
  // Supersets and rotations (M9)
  static String groupKind(PlanGroupKind k) => switch (k) {
    PlanGroupKind.superset => 'Superset',
    PlanGroupKind.rotation => 'Rotation',
  };
  static String createGroup(PlanGroupKind k) => switch (k) {
    PlanGroupKind.superset => 'Superset erstellen',
    PlanGroupKind.rotation => 'Rotation erstellen',
  };
  static String groupCreateHint(PlanGroupKind k) => switch (k) {
    PlanGroupKind.superset =>
      'Wähle mindestens zwei Übungen. Sie werden abwechselnd trainiert, '
          'die Pause läuft erst nach jeder Runde.',
    PlanGroupKind.rotation =>
      'Wähle mindestens zwei Übungen. Pro Training ist nur eine davon dran, '
          'beim nächsten Training dieses Plans die nächste.',
  };
  static String groupInfo(PlanGroupKind k) => switch (k) {
    PlanGroupKind.superset =>
      'Übungen eines Supersets machst du abwechselnd ohne Pause '
          'dazwischen:\n\n'
          'Übung A Satz 1, Übung B Satz 1, Pause, A Satz 2, B Satz 2, '
          'Pause …\n\n'
          'Nach jedem Satz springt das Training automatisch zur nächsten Übung '
          'des Supersets. Der Pausentimer startet erst nach dem letzten Satz '
          'einer Runde. Die Pause stellst du für das ganze Superset ein; ohne '
          'eigene Einstellung gilt die Pause der letzten Übung.\n\n'
          'Haben die Übungen unterschiedlich viele Sätze, läuft die Übung mit '
          'mehr Sätzen am Ende allein weiter.\n\n'
          'Im Plan verschiebst du ein Superset als Ganzes am Griff oben; die '
          'Reihenfolge innerhalb änderst du an den Griffen der Übungen.',
    PlanGroupKind.rotation =>
      'In einer Rotation wechseln sich Übungen von Training zu Training ab, '
          'z. B. Bizepscurls mit Hantel und am Seilzug.\n\n'
          'Beim Start eines Trainings dieses Plans kommt nur die Übung, die '
          'gerade dran ist, ins Training. Die anderen sind ausgegraut.\n\n'
          'Die Rotation rückt weiter, wenn du das Training beendest und die '
          'Übung dabei mindestens einen Satz hatte. Wird sie übersprungen, '
          'bleibt sie beim nächsten Mal dran.\n\n'
          'Mit „Wechsel nach …“ bleibt jede Übung mehrere Trainings dran. '
          'Welche Übung als Nächstes kommt, kannst du jederzeit selbst wählen.',
  };
  static const groupNeedsTwo =
      'Dafür brauchst du mindestens zwei Übungen, die noch in keinem Superset '
      'und keiner Rotation sind.';
  static String groupOptions(PlanGroupKind k) => '${groupKind(k)}-Optionen';
  static String moveGroup(PlanGroupKind k) => '${groupKind(k)} verschieben';
  static String supersetRest(String rest) => 'Pause $rest nach jeder Runde';
  static const supersetRestDefault = 'Pause wie bei letzter Übung';
  static const supersetRestTitle = 'Pause nach jeder Runde';
  static const supersetRestOption = 'Pause einstellen';
  static const supersetRestDialogDefault = 'wie bei letzter Übung';
  static String rotationEvery(int n) =>
      n == 1 ? 'Wechsel nach jedem Training' : 'Wechsel nach $n Trainings';
  static const rotationEveryTitle = 'Übung wechseln nach';
  static const rotationEveryOption = 'Wechsel einstellen';
  static String trainingsUnit(int n) => n == 1 ? 'Training' : 'Trainings';
  static const rotationDue = 'Ist dran';
  static String rotationDueLeft(int n) =>
      n == 1 ? 'Ist dran · noch 1 Training' : 'Ist dran · noch $n Trainings';
  static const rotationLater = 'Später';
  static const rotationMakeDue = 'Als Nächstes trainieren';
  static String removeFromGroup(PlanGroupKind k) => switch (k) {
    PlanGroupKind.superset => 'Aus Superset nehmen',
    PlanGroupKind.rotation => 'Aus Rotation nehmen',
  };
  static const dissolve = 'Auflösen';
  static const whichExercise = 'Welche Übung?';
  static String supersetRound(int round, int rounds) =>
      'Runde $round von $rounds';

  // Explanations behind the info icons (M9)
  static const explain = 'Erklärung';
  static String metricInfo(ExerciseMetric m) => switch (m) {
    ExerciseMetric.estimatedOneRepMax =>
      'Das Gewicht, das du schätzungsweise genau einmal heben könntest '
          '(One-Rep-Max, 1RM). Berechnet nach der Epley-Formel aus jedem Satz:\n\n'
          'Gewicht × (1 + Wdh / 30), bei 1 Wdh das Gewicht selbst.\n\n'
          'Beispiel: 80 kg × 8 Wdh ergibt 80 × (1 + 8/30) ≈ 101,3 kg.\n\n'
          'Pro Training zählt der beste Satz. So lassen sich Sätze mit '
          'unterschiedlich vielen Wiederholungen vergleichen – steigt der Wert, '
          'bist du stärker geworden.',
    ExerciseMetric.maxWeight =>
      'Das höchste Gewicht, das du in einem Satz dieses Trainings bewegt '
          'hast – unabhängig davon, wie viele Wiederholungen es waren.',
    ExerciseMetric.volume =>
      'Das insgesamt bewegte Gewicht dieser Übung im Training: die Summe aus '
          'Gewicht × Wiederholungen über alle Sätze.\n\n'
          'Beispiel: 3 Sätze × 10 Wdh mit 60 kg = 1.800 kg.\n\n'
          'Das Volumen zeigt die Trainingsmenge, nicht die Maximalkraft.',
    ExerciseMetric.maxReps =>
      'Die meisten Wiederholungen in einem Satz dieses Trainings.',
    ExerciseMetric.totalReps =>
      'Alle Wiederholungen dieser Übung im Training zusammen.',
    ExerciseMetric.maxAddedWeight =>
      'Das höchste Zusatzgewicht eines Satzes (z. B. Gewichtsgürtel). '
          'Negative Werte bedeuten Unterstützung (z. B. Gummiband, Maschine).',
    ExerciseMetric.effectiveOneRepMax =>
      'Wie das geschätzte 1RM, aber mit der effektiven Last: dein '
          'Körpergewicht (Eintrag mit dem nächstgelegenen Datum) plus '
          'Zusatzgewicht.\n\n'
          'Beispiel: 80 kg Körpergewicht, +10 kg, 6 Wdh ergibt '
          '90 × (1 + 6/30) = 108 kg.\n\n'
          'Nur verfügbar, wenn du im Tab Körper Gewicht eingetragen hast.',
    ExerciseMetric.maxDuration => 'Der längste Satz dieses Trainings.',
    ExerciseMetric.totalDuration =>
      'Die Dauer aller Sätze dieser Übung im Training zusammen.',
  };
  static const strengthIndexInfo =
      'Deine Kraftentwicklung über mehrere Übungen in einer Zahl.\n\n'
      'Für jede Übung mit „Im Kraftindex berücksichtigen“ wird pro Woche der '
      'beste Leistungswert durch den Wert ihres ersten Trainings geteilt. '
      'Leistungswert: bei Gewicht × Wdh das geschätzte 1RM, bei Körpergewicht '
      'das 1RM mit Körpergewicht (ohne Körpergewicht-Einträge: Max. Wdh), bei '
      'Zeit die Max. Dauer.\n\n'
      'Der Kraftindex ist der Durchschnitt dieser Verhältnisse: 100 % = dein '
      'Startniveau, 110 % = im Schnitt 10 % stärker als am Anfang.\n\n'
      'Wird eine Übung eine Woche nicht trainiert, zählt ihr letzter Wert '
      'weiter, höchstens 8 Wochen lang.\n\n'
      'Welche Übungen zählen, stellst du je Übung ein. Der Verlauf wird bei '
      'jeder Änderung komplett neu berechnet.';
  static const weeklyVolumeInfo =
      'Das insgesamt bewegte Gewicht einer Kalenderwoche (Mo–So): die Summe aus '
      'Gewicht × Wiederholungen aller Sätze von Übungen mit Gewicht × Wdh.\n\n'
      'Beispiel: 3 × 10 mit 60 kg = 1.800 kg.\n\n'
      'Körpergewichts- und Zeitübungen zählen nicht mit. Das Volumen zeigt die '
      'Trainingsmenge, nicht die Maximalkraft.';
  static const calendarInfo =
      'Jedes Kästchen ist ein Tag der letzten 26 Wochen (Spalten = Wochen, '
      'Zeilen = Mo–So). Je kräftiger die Farbe, desto mehr Sätze.\n\n'
      'Ø Trainings pro Woche bezieht sich auf den gewählten Zeitraum.';
  static const streakInfo =
      'Deine Serie zählt die Wochen (Mo–So) in Folge mit mindestens einem '
      'Training.\n\n'
      'Die laufende Woche zählt mit, sobald du trainiert hast. Solange sie '
      'noch leer ist, bleibt die Serie bestehen. Fällt eine ganze Woche aus, '
      'ist die Serie vorbei.\n\n'
      'Die längste Serie bleibt als Bestwert stehen, auch wenn sie nicht mehr '
      'aktiv ist.';
  static const recordsInfo =
      'Rekorde sind Bestwerte je Übung:\n\n'
      '• Gewicht × Wdh: geschätztes 1RM (Epley: Gewicht × (1 + Wdh / 30)) und '
      'höchstes Gewicht\n'
      '• Körpergewicht: meiste Wdh und höchstes Zusatzgewicht\n'
      '• Zeit: längste Dauer\n\n'
      'Ein Satz ist ein Rekord, wenn er alle früheren Sätze der Übung '
      'übertrifft. Das erste Training einer Übung setzt nur den Startwert.';
  static const strengthIndexFieldInfo =
      'Ist der Schalter an, fließt diese Übung in den Kraftindex ein '
      '(Statistik, Tab Gesamt): Ihr Fortschritt gegenüber dem ersten Training wird '
      'zusammen mit den anderen Übungen gemittelt.\n\n'
      'Schaltest du ihn aus, wird der Kraftindex für den gesamten Verlauf ohne '
      'diese Übung neu berechnet – auch rückwirkend. Schaltest du ihn wieder '
      'ein, ist sie ebenso rückwirkend wieder enthalten.\n\n'
      'Deine Trainingsdaten bleiben dabei unverändert.\n\n'
      'Sinnvoll für Übungen, an denen du deine Kraft messen willst; eher aus '
      'für Aufwärm-, Dehn- oder Technikübungen.';

  static const statBest = 'Bestwert';
  static const statChange = 'Veränderung';
  static const statTrainings = 'Trainings';
  static const lastTrainings = 'Letzte Trainings';
  static const strengthIndex = 'Kraftindex';
  static String strengthIndexSubtitle(int n) =>
      n == 1 ? 'Durchschnitt über 1 Übung' : 'Durchschnitt über $n Übungen';
  static const strengthIndexEmpty =
      'Für den Kraftindex brauchst du Trainings mit Übungen, die im Kraftindex '
      'zählen.';
  static const weeklyVolume = 'Wochenvolumen';
  static const volumeEmpty = 'Noch kein Volumen im Zeitraum.';
  static const calendar = 'Trainingskalender';
  static const calendarSubtitle = 'Letzte 26 Wochen · Sätze pro Tag';
  static String perWeek(String n) => 'Ø $n Trainings pro Woche';
  static const streakTitle = 'Serie';
  static String streakWeeksLabel(int n) =>
      n == 1 ? 'Woche in Folge' : 'Wochen in Folge';
  static const streakNone = 'Keine aktive Serie';
  static const streakStart = 'Trainiere diese Woche, um eine neue zu starten.';
  static const streakKeep = 'Trainiere diese Woche, um sie zu halten.';
  static const streakIsLongest = 'Deine längste Serie bisher';
  static String streakLongest(int n) =>
      'Längste Serie: ${n == 1 ? '1 Woche' : '$n Wochen'} · nicht aktiv';
  static const weekdayInitials = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  static const trainingDuration = 'Trainingsdauer';
  static const durationEmpty = 'Noch keine Trainings im Zeitraum.';
  static const setsPerCategory = 'Sätze pro Kategorie';
  static const categoryEmpty = 'Noch keine Sätze im Zeitraum.';
  static const bodyWeightChartEmpty =
      'Keine Körpergewicht-Einträge im Zeitraum.';
  static const recordsEmpty = 'Noch keine Rekorde.';
  static String minutes(int n) => '$n min';

  // Settings sections (SPEC §6.7)
  static const sectionTraining = 'Training';
  static const sectionAppearance = 'Darstellung';
  static const sectionData = 'Daten';
  static const sectionAbout = 'Über';
  static const settingDefaultSets = 'Standard-Satzanzahl';
  static const settingDefaultRest = 'Standard-Pause';
  static const settingDefaultStep = 'Standard-Steigerung';
  static const settingDefaultStepSubtitle =
      'Für Übungen mit Gewichtsschritten „Standard“, z. B. Geräte mit '
      '15-lbs-Scheiben. Angezeigt wird immer kg.';
  static const settingRestTimer = 'Pausentimer';
  static const settingVibration = 'Vibration';
  static const settingKeepScreenOn = 'Display anlassen';
  static const settingKeepScreenOnSubtitle = 'Während eines Trainings';
  static const settingAutoActivate = 'Nächste Übung automatisch aktivieren';
  static const themeSystem = 'System';
  static const themeLight = 'Hell';
  static const themeDark = 'Dunkel';
  static const exportCsv = 'CSV exportieren';
  static const exportCsvSubtitle =
      'ZIP mit Sätzen, Trainings, Körpergewicht, Übungen';
  static const createBackup = 'Backup erstellen';
  static const restoreBackup = 'Backup wiederherstellen';
  static const restoreBlocked = 'Während eines Trainings nicht möglich.';
  static String lastBackup(String when) => 'Letztes Backup: $when';
  static const noBackupYet = 'Noch kein Backup erstellt';
  static const backupReminder = 'Backup-Erinnerung';
  static const backupReminderOff = 'aus';
  static String days(int n) => n == 1 ? '1 Tag' : '$n Tage';
  static const shareAction = 'Teilen';
  static const saveAsAction = 'Speichern unter …';
  static const exportFailed =
      'Export fehlgeschlagen. Deine Daten sind unverändert – bitte versuche es '
      'noch einmal.';
  static const appVersion = 'App-Version';
  static const buildNumber = 'Build-Nummer';
  static const schemaVersion = 'Datenbank-Schemaversion';
  static const licenses = 'Lizenzen';

  // Import (SPEC §8.3)
  static const restoreTitle = 'Backup wiederherstellen?';
  static String restorePreview(int trainings, String period, int weights) =>
      '$trainings Trainings$period, $weights Körpergewicht-Einträge.';
  static String restorePeriod(String from, String to) => ' vom $from bis $to';
  static const restoreWarning =
      'Alle aktuellen Daten werden ersetzt. Vorher wird automatisch eine '
      'Sicherheitskopie deines aktuellen Stands angelegt.';
  static const restoreConfirm = 'Wiederherstellen';
  static const restoreFailed =
      'Wiederherstellen fehlgeschlagen. Deine bisherigen Daten sind unverändert.';
  static const importErrorTitle = 'Datei kann nicht importiert werden';
  static const importNotJson =
      'Die Datei ist kein GymLog-Backup (kein lesbares JSON). Wähle eine Datei '
      '„gymlog-backup-….json“.';
  static const importWrongFormat =
      'Die Datei ist kein GymLog-Backup. Wähle eine Datei „gymlog-backup-….json“.';
  static const importNewerVersion =
      'Das Backup stammt von einer neueren GymLog-Version. Aktualisiere die App '
      'und versuche es erneut.';
  static const importInvalid =
      'Das Backup ist beschädigt oder unvollständig. Nichts wurde geändert.';

  // Backup reminder in the summary (SPEC §6.3)
  static String backupAgo(int days) => 'Letztes Backup vor $days Tagen';

  // Errors
  static const errorInvalidValue =
      'Ein Wert liegt außerhalb des erlaubten Bereichs.';
  static const errorNotFound =
      'Der Eintrag existiert nicht mehr. Die Ansicht wurde aktualisiert.';
  static const errorDuplicateExercise = 'Diese Übung ist schon enthalten.';
  static const errorActiveSession =
      'Es läuft schon ein Training. Beende es zuerst.';
  static const errorSessionNotActive = 'Dieses Training ist schon beendet.';
  static const errorInvalidSet = 'Die Werte des Satzes sind ungültig.';
  static const errorUnexpected =
      'Das hat nicht geklappt. Deine Daten sind unverändert – bitte versuche '
      'es noch einmal.';

  // Units
  static const unitKg = 'kg';
  static const unitLbs = 'lbs';
  static String unit(WeightUnit u) => switch (u) {
    WeightUnit.kg => unitKg,
    WeightUnit.lbs => unitLbs,
  };

  // Notifications (1.2.0)
  static const sectionNotifications = 'Benachrichtigungen';
  static String notifyEveningTitle(String plan, String time) =>
      'Morgen um $time: $plan';
  static const notifyEveningBody = 'Denk dran, einen Slot zu buchen.';
  static const bookSlot = 'Slot buchen';
  static String notifyBeforeTitle(int minutes, String plan) =>
      'In ${_inTime(minutes)}: $plan';
  static String _inTime(int minutes) => minutes % 60 != 0
      ? '$minutes Minuten'
      : minutes == 60
      ? '1 Stunde'
      : '${minutes ~/ 60} Stunden';
  static const notifyOpenSessionTitle = 'Training noch offen';
  static const notifyOpenSessionBody =
      'Seit 3 Stunden kein neuer Satz. Tippe, um es zu beenden oder '
      'weiterzumachen.';
  static const notifyBackupTitle = 'Zeit für ein Backup';
  static const notifyBackupBody =
      'Sichere deine Trainings in den Einstellungen unter „Daten“.';
  static const notifyStreakTitle = 'Deine Serie ist in Gefahr';
  static String notifyStreakBody(int weeks) =>
      '${weeks == 1 ? '1 Woche' : '$weeks Wochen'} in Folge – trainiere bis '
      'Sonntag, damit sie hält.';
  static String notifyUpdateTitle(String version) => 'GymLog $version ist da';
  static const notifyUpdateBody = 'Tippe, um die neue Version zu laden.';
  static const notifyRestTitle = 'Pause';
  static const notifyRestBody = 'Danach geht es mit dem nächsten Satz weiter.';

  // Settings → Benachrichtigungen
  static const settingNotifyEvening = 'Abend vorher';
  static String settingNotifyEveningSubtitle(String time) =>
      'Um $time an den Trainingstag erinnern, mit „Slot buchen“';
  static const settingNotifyBefore = 'Vor dem Training';
  static String settingNotifyBeforeSubtitle(int minutes) =>
      '${_inTime(minutes)} vorher, mit Motivationsspruch';
  static const settingBeforeMinutes = 'Wie lange vorher';
  static const settingNotifyRest = 'Pause auf dem Sperrbildschirm';
  static const settingNotifyRestSubtitle =
      'Countdown, wenn GymLog im Hintergrund ist';
  static const settingNotifyOpenSession = 'Training noch offen';
  static const settingNotifyOpenSessionSubtitle =
      '3 Stunden nach dem letzten Satz';
  static const settingNotifyBackup = 'Backup-Erinnerung';
  static const settingNotifyBackupSubtitle =
      'Wenn das letzte Backup älter ist als eingestellt';
  static const settingNotifyStreak = 'Serie in Gefahr';
  static const settingNotifyStreakSubtitle =
      'Samstag 18 Uhr, wenn diese Woche noch kein Training war';
  static const settingCheckUpdates = 'Nach Updates suchen';
  static const settingCheckUpdatesSubtitle =
      'Einmal am Tag auf GitHub nachsehen (einziger Internetzugriff)';
  static const settingBookingUrl = 'Buchungsseite';
  static const settingBookingUrlHint = 'https://…';
  static const errorBookingUrl =
      'Gib eine Adresse ein, die mit https:// beginnt.';
  static String updateAvailable(String version) =>
      'Neue Version $version verfügbar';
  static const updateDownload = 'Herunterladen';

  // Plans: training days
  static const planSchedule = 'Trainingstage';
  static const planScheduleTitle = 'Trainingstage und Uhrzeit';
  static const planActive = 'Aktiv';
  static const planActiveSubtitle =
      'Wird gerade trainiert: Erinnerungen an diesen Tagen. Inaktive Pläne '
      'sind ausgegraut.';
  static const weekdays = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];
  static const changeTime = 'Uhrzeit ändern';
  static String planScheduleSummary(List<String> days) => days.join(', ');
  static const noTrainingDays = 'Keine festen Trainingstage';
  static const planInactive = 'inaktiv';

  /// Motivational lines for the reminder before a training (1.2.0).
  static const motivation = [
    'Keine Ausreden, du faule Sau. Die Hanteln warten nicht.',
    'Nicht nur LLMs wollen trainiert werden. Heute bist du dran.',
    'Deine Muskeln haben einen Pull Request gestellt. Approve it.',
    'Gradient Descent gilt auch fürs Bauchfett: ein Schritt nach dem anderen.',
    'Overfitting aufs Sofa erkannt. Mehr Trainingsdaten nötig!',
    'Your body called. It wants more than 2 FPS.',
    'Skip leg day? Segmentation fault (core dumped).',
    'Hardware-Upgrade fällig. Bitte im Studio abholen.',
    'Kein Training ist wie Code ohne Tests: rächt sich später.',
    'Torque it up! Deine Aktuatoren brauchen Last.',
    'Wer rastet, der rostet. Frag mal die alten Industrieroboter.',
    'Dein Sofa hat 99 % Uptime. Zeit für einen geplanten Ausfall.',
    'Loss Function: Ausreden. Minimiere sie.',
    'sudo make me strong – funktioniert nur im Studio.',
    'while (alive) { train(); } – heute kein break.',
    'Muskelkater ist nur ein Warning, kein Error.',
    'Error 404: Motivation not found. Zum Glück gibt es Disziplin.',
    'Your neural net is fine. Your glutes need backprop.',
    'Kein Roboter wird im Standby-Modus stärker.',
    'Die KI kann dir viel abnehmen. Die Klimmzüge nicht.',
    'Echtzeit-Anforderung: Training startet bald. Keine Latenz!',
    'Deine Endeffektoren vermissen die Langhantel.',
    'Reinforcement Learning live: Reward ist der Pump.',
    'Du bist kein Embedded-System. Du darfst mehr als 3 Watt verbrauchen.',
    'Merge-Konflikt zwischen Couch und Gym? Gym gewinnt.',
    'Kalibrierung abgeschlossen. Jetzt fehlt nur noch die Last.',
    'Faul rumliegen kann jeder Staubsaugerroboter. Du kannst mehr.',
    'Deploy to production: dein Bizeps. Heute.',
    'Low battery? Das Studio ist deine Ladestation.',
    'Attention is all you need – und ein bisschen Eisen.',
    'Schwach sein ist ein Bug. Training ist der Fix.',
    'Your gains are not going to train themselves. Not even with GPUs.',
  ];
}
