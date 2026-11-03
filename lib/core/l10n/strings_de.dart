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
  static const exercisesEmpty = 'Noch keine Übungen. Lege deine erste an.';
  static const exercisesNoMatch = 'Keine Übung passt zur Suche.';
  static const allCategories = 'Alle';
  static const newExercise = 'Neue Übung';
  static const archiveTitle = 'Archiv';
  static const archiveEmpty = 'Keine archivierten Übungen.';
  static const openArchive = 'Archiv öffnen';
  static String exerciseRestored(String name) => '„$name“ wiederhergestellt.';
  static String exerciseDeleted(String name) => '„$name“ gelöscht.';
  static String exerciseArchived(String name) =>
      '„$name“ archiviert. Der Verlauf bleibt erhalten.';
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
  static const fieldIncrement = 'Steigerung in kg';
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
  static const errorNameRequired = 'Gib einen Namen ein.';
  static const errorNameTooLong = 'Höchstens 60 Zeichen.';
  static const errorExerciseNameTaken =
      'Es gibt schon eine Übung mit diesem Namen (auch im Archiv).';
  static const errorPlanNameTaken =
      'Es gibt schon einen Plan mit diesem Namen.';
  static const errorIncrement = 'Gib eine Zahl größer als 0 ein, z. B. 2,5.';
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
  static String planDeleted(String name) => 'Plan „$name“ gelöscht.';

  // Training tab (no active session)
  static const freeTraining = 'Frei';
  static const freeTrainingTitle = 'Freies Training';
  static const freeEmpty = 'Füge Übungen hinzu oder starte direkt.';
  static const planEmpty = 'Dieser Plan hat noch keine Übungen.';
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
  static const pickerEmpty = 'Noch keine Übungen in der Bibliothek.';

  // Active session (SPEC §6.2)
  static const finishTraining = 'Beenden';
  static String setOf(int n, int total) => 'Satz $n von $total';
  static String progress(int n, int total) => '$n/$total';
  static String lastTimeOn(String date, String summary) =>
      'Letztes Mal ($date): $summary';
  static const saveSet = 'Satz speichern';
  static const setSaved = 'Satz gespeichert';
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
  static const setDeleted = 'Satz gelöscht.';
  static const ok = 'OK';
  static String openExercisesTitle(int n) => n == 1
      ? '1 Übung ist nicht abgeschlossen. Training trotzdem beenden?'
      : '$n Übungen sind nicht abgeschlossen. Training trotzdem beenden?';
  static const discardNoSetsTitle = 'Keine Sätze erfasst. Training verwerfen?';
  static const keepTraining = 'Weiter trainieren';
  static const discard = 'Verwerfen';
  static const trainingDiscarded = 'Training verworfen.';
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
      'Reihenfolge und neue Übungen in Plan „$plan“ übernehmen';
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
  static String removedFromSession(String name) => '„$name“ entfernt.';
  static const noSetsRecorded = 'Keine Sätze erfasst.';

  // Body weight (SPEC §6.6)
  static const today = 'Heute';
  static const weightKgLabel = 'Gewicht in kg';
  static const saved = 'Gespeichert.';
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
  static const showBodyWeight = 'Körpergewicht einblenden';
  static const weeklyVolume = 'Wochenvolumen';
  static const volumeEmpty = 'Noch kein Volumen im Zeitraum.';
  static const calendar = 'Trainingskalender';
  static const calendarSubtitle = 'Letzte 26 Wochen · Sätze pro Tag';
  static String perWeek(String n) => 'Ø $n Trainings pro Woche';
  static String streak(int n) =>
      n == 1 ? 'Serie: 1 Woche in Folge' : 'Serie: $n Wochen in Folge';
  static const weekdayInitials = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  static const trainingDuration = 'Trainingsdauer';
  static const durationEmpty = 'Noch keine Trainings im Zeitraum.';
  static const setsPerCategory = 'Sätze pro Kategorie';
  static const categoryEmpty = 'Noch keine Sätze im Zeitraum.';
  static const bodyWeightChartEmpty =
      'Keine Körpergewicht-Einträge im Zeitraum.';
  static const recordsEmpty = 'Noch keine Rekorde.';
  static String minutes(int n) => '$n min';

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
}
