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

  // Units
  static const unitKg = 'kg';
}
