import 'copy.dart';
import 'enums.dart';

/// The single settings row (table `app_settings`, `id` = 1).
final class AppSettings {
  const AppSettings({
    this.id = singletonId,
    this.defaultSets = 3,
    this.defaultRestSec = 90,
    this.restTimerEnabled = true,
    this.vibrationEnabled = true,
    this.keepScreenOn = true,
    this.autoActivateNext = false,
    this.themeMode = ThemePreference.system,
    this.lastSelectedPlanId,
    this.lastBackupAt,
    this.backupReminderDays = 30,
    this.defaultStep = 15,
    this.defaultStepUnit = WeightUnit.lbs,
    this.notifyEvening = true,
    this.eveningMinute = 20 * 60,
    this.notifyBefore = true,
    this.beforeMinutes = 60,
    this.notifyRest = true,
    this.notifyOpenSession = true,
    this.notifyBackup = true,
    this.notifyStreak = true,
    this.checkUpdates = true,
    this.bookingUrl = defaultBookingUrl,
    this.lastUpdateCheckAt,
    this.latestVersion,
    this.notificationsAsked = false,
    this.hrDeviceId,
    this.hrDeviceName,
    this.hrMax,
    this.hrThreshold,
    this.birthYear,
    this.sex,
    this.hrWarnBpm,
    this.hrPauseBpm,
  });

  /// Booking page of the user's gym (1.2.0); changeable in the settings.
  static const defaultBookingUrl =
      'https://optioffice.eu/optioffice/login/homepagemodul.php'
      '?s=2070&c=303161843&action=termin&t=19192&i=0';

  static const singletonId = 1;

  /// Defaults of a fresh installation (SPEC §5).
  static const defaults = AppSettings();

  /// Always [singletonId].
  final int id;
  final int defaultSets;
  final int defaultRestSec;
  final bool restTimerEnabled;
  final bool vibrationEnabled;
  final bool keepScreenOn;
  final bool autoActivateNext;
  final ThemePreference themeMode;

  /// `null` = "Frei".
  final int? lastSelectedPlanId;

  /// UTC.
  final DateTime? lastBackupAt;

  /// 0 = reminder off.
  final int backupReminderDays;

  /// Default weight step of exercises with [StepMode.standard] (1.1.0),
  /// in [defaultStepUnit].
  final double defaultStep;
  final WeightUnit defaultStepUnit;

  // 1.2.0: notifications.

  /// Evening before a training day: reminder with booking button.
  final bool notifyEvening;

  /// Time of the evening reminder, minutes after midnight.
  final int eveningMinute;

  /// Reminder with a motivational line before a training.
  final bool notifyBefore;

  /// How long before the training.
  final int beforeMinutes;

  /// Rest countdown on the lock screen.
  final bool notifyRest;

  /// A training still open 3 hours after the last set.
  final bool notifyOpenSession;

  /// Backup reminder as a notification.
  final bool notifyBackup;

  /// Saturday 18:00 when the streak would end this week.
  final bool notifyStreak;

  /// Once a day: is there a newer release on GitHub?
  final bool checkUpdates;

  /// Booking page of the gym, opened by „Slot buchen“.
  final String bookingUrl;

  /// UTC, last successful look for updates.
  final DateTime? lastUpdateCheckAt;

  /// Newest version seen on GitHub (e.g. `1.3.0`); notified once.
  final String? latestVersion;

  /// The Android notification permission was asked for once.
  final bool notificationsAsked;

  /// The Bluetooth heart rate monitor (1.5.0): its address, null = none.
  /// Device state like [notificationsAsked]: not part of backups.
  final String? hrDeviceId;

  /// Its name as advertised, e.g. "Forerunner 255".
  final String? hrDeviceName;

  /// Maximum heart rate of 1.6.0; unused since 1.6.1 (the zones follow the
  /// lactate threshold), kept because the column stays (rule 4).
  final int? hrMax;

  /// Heart rate profile (1.6.1, Körper tab): lactate threshold heart rate
  /// ("LSHF" at Garmin); the zones are shares of it.
  final int? hrThreshold;

  /// Birth year and sex: only for the calorie estimate.
  final int? birthYear;
  final Sex? sex;

  /// Warn above this heart rate; null = no warning.
  final int? hrWarnBpm;

  /// "Pause nach Puls" ends below this; null = top of range 1.
  final int? hrPauseBpm;

  /// The pause limit in use: own value or the top of zone 1 (67 % of the
  /// threshold − 1).
  int? get pauseBpm =>
      hrPauseBpm ??
      (hrThreshold == null ? null : (hrThreshold! * 0.67).round() - 1);

  AppSettings copyWith({
    int? defaultSets,
    int? defaultRestSec,
    bool? restTimerEnabled,
    bool? vibrationEnabled,
    bool? keepScreenOn,
    bool? autoActivateNext,
    ThemePreference? themeMode,
    Object? lastSelectedPlanId = unset,
    Object? lastBackupAt = unset,
    int? backupReminderDays,
    double? defaultStep,
    WeightUnit? defaultStepUnit,
    bool? notifyEvening,
    int? eveningMinute,
    bool? notifyBefore,
    int? beforeMinutes,
    bool? notifyRest,
    bool? notifyOpenSession,
    bool? notifyBackup,
    bool? notifyStreak,
    bool? checkUpdates,
    String? bookingUrl,
    Object? lastUpdateCheckAt = unset,
    Object? latestVersion = unset,
    bool? notificationsAsked,
    Object? hrDeviceId = unset,
    Object? hrDeviceName = unset,
    Object? hrMax = unset,
    Object? hrThreshold = unset,
    Object? birthYear = unset,
    Object? sex = unset,
    Object? hrWarnBpm = unset,
    Object? hrPauseBpm = unset,
  }) {
    return AppSettings(
      id: id,
      defaultSets: defaultSets ?? this.defaultSets,
      defaultRestSec: defaultRestSec ?? this.defaultRestSec,
      restTimerEnabled: restTimerEnabled ?? this.restTimerEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      autoActivateNext: autoActivateNext ?? this.autoActivateNext,
      themeMode: themeMode ?? this.themeMode,
      lastSelectedPlanId: pick<int?>(
        lastSelectedPlanId,
        this.lastSelectedPlanId,
      ),
      lastBackupAt: pick<DateTime?>(lastBackupAt, this.lastBackupAt),
      backupReminderDays: backupReminderDays ?? this.backupReminderDays,
      defaultStep: defaultStep ?? this.defaultStep,
      defaultStepUnit: defaultStepUnit ?? this.defaultStepUnit,
      notifyEvening: notifyEvening ?? this.notifyEvening,
      eveningMinute: eveningMinute ?? this.eveningMinute,
      notifyBefore: notifyBefore ?? this.notifyBefore,
      beforeMinutes: beforeMinutes ?? this.beforeMinutes,
      notifyRest: notifyRest ?? this.notifyRest,
      notifyOpenSession: notifyOpenSession ?? this.notifyOpenSession,
      notifyBackup: notifyBackup ?? this.notifyBackup,
      notifyStreak: notifyStreak ?? this.notifyStreak,
      checkUpdates: checkUpdates ?? this.checkUpdates,
      bookingUrl: bookingUrl ?? this.bookingUrl,
      lastUpdateCheckAt: pick<DateTime?>(
        lastUpdateCheckAt,
        this.lastUpdateCheckAt,
      ),
      latestVersion: pick<String?>(latestVersion, this.latestVersion),
      notificationsAsked: notificationsAsked ?? this.notificationsAsked,
      hrDeviceId: pick<String?>(hrDeviceId, this.hrDeviceId),
      hrDeviceName: pick<String?>(hrDeviceName, this.hrDeviceName),
      hrMax: pick<int?>(hrMax, this.hrMax),
      hrThreshold: pick<int?>(hrThreshold, this.hrThreshold),
      birthYear: pick<int?>(birthYear, this.birthYear),
      sex: pick<Sex?>(sex, this.sex),
      hrWarnBpm: pick<int?>(hrWarnBpm, this.hrWarnBpm),
      hrPauseBpm: pick<int?>(hrPauseBpm, this.hrPauseBpm),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.id == id &&
      other.defaultSets == defaultSets &&
      other.defaultRestSec == defaultRestSec &&
      other.restTimerEnabled == restTimerEnabled &&
      other.vibrationEnabled == vibrationEnabled &&
      other.keepScreenOn == keepScreenOn &&
      other.autoActivateNext == autoActivateNext &&
      other.themeMode == themeMode &&
      other.lastSelectedPlanId == lastSelectedPlanId &&
      other.lastBackupAt == lastBackupAt &&
      other.backupReminderDays == backupReminderDays &&
      other.defaultStep == defaultStep &&
      other.defaultStepUnit == defaultStepUnit &&
      other.notifyEvening == notifyEvening &&
      other.eveningMinute == eveningMinute &&
      other.notifyBefore == notifyBefore &&
      other.beforeMinutes == beforeMinutes &&
      other.notifyRest == notifyRest &&
      other.notifyOpenSession == notifyOpenSession &&
      other.notifyBackup == notifyBackup &&
      other.notifyStreak == notifyStreak &&
      other.checkUpdates == checkUpdates &&
      other.bookingUrl == bookingUrl &&
      other.lastUpdateCheckAt == lastUpdateCheckAt &&
      other.latestVersion == latestVersion &&
      other.notificationsAsked == notificationsAsked &&
      other.hrDeviceId == hrDeviceId &&
      other.hrDeviceName == hrDeviceName &&
      other.hrMax == hrMax &&
      other.hrThreshold == hrThreshold &&
      other.birthYear == birthYear &&
      other.sex == sex &&
      other.hrWarnBpm == hrWarnBpm &&
      other.hrPauseBpm == hrPauseBpm;

  @override
  int get hashCode => Object.hashAll([
    id,
    defaultSets,
    defaultRestSec,
    restTimerEnabled,
    vibrationEnabled,
    keepScreenOn,
    autoActivateNext,
    themeMode,
    lastSelectedPlanId,
    lastBackupAt,
    backupReminderDays,
    defaultStep,
    defaultStepUnit,
    notifyEvening,
    eveningMinute,
    notifyBefore,
    beforeMinutes,
    notifyRest,
    notifyOpenSession,
    notifyBackup,
    notifyStreak,
    checkUpdates,
    bookingUrl,
    lastUpdateCheckAt,
    latestVersion,
    notificationsAsked,
    hrDeviceId,
    hrDeviceName,
    hrMax,
    hrThreshold,
    birthYear,
    sex,
    hrWarnBpm,
    hrPauseBpm,
  ]);
}
