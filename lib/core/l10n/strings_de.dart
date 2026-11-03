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
  static const trainingEmpty =
      'Hier planst und startest du bald dein Training.';
  static const historyEmpty =
      'Noch keine Trainings. Starte dein erstes im Tab Training.';
  static const statsEmpty =
      'Sobald du trainierst, siehst du hier deine Fortschritte.';
  static const bodyEmpty = 'Hier trägst du bald dein Körpergewicht ein.';
  static const settingsEmpty = 'Die Einstellungen folgen in Kürze.';

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

  // Units
  static const unitKg = 'kg';
}
