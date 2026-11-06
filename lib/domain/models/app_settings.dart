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
  });

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
      other.backupReminderDays == backupReminderDays;

  @override
  int get hashCode => Object.hash(
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
  );
}
