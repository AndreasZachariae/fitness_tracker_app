import '../../domain/models/models.dart';
import '../db/database.dart';
import '../db/storage_time.dart';
import 'repository_exceptions.dart';

/// The single settings row.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Stream<AppSettings> watch() => _db.settingsDao.watch();

  Future<AppSettings> get() => _db.settingsDao.get();

  /// Applies [change] to the current settings and saves the result.
  Future<AppSettings> update(AppSettings Function(AppSettings) change) =>
      _db.transaction(() async {
        final changed = change(await _db.settingsDao.get());
        _validate(changed);
        final planId = changed.lastSelectedPlanId;
        if (planId != null && await _db.plansDao.findById(planId) == null) {
          throw NotFoundException('plan', planId);
        }
        final normalized = changed.copyWith(
          lastBackupAt: changed.lastBackupAt == null
              ? null
              : storageTime(changed.lastBackupAt!),
          lastUpdateCheckAt: changed.lastUpdateCheckAt == null
              ? null
              : storageTime(changed.lastUpdateCheckAt!),
          bookingUrl: changed.bookingUrl.trim(),
        );
        await _db.settingsDao.write(normalized);
        return normalized;
      });

  static void _validate(AppSettings s) {
    if (s.id != AppSettings.singletonId) {
      throw InvalidValueException('id', s.id);
    }
    if (s.defaultSets < 1 || s.defaultSets > 10) {
      throw InvalidValueException('defaultSets', s.defaultSets);
    }
    // 1.2.0
    if (s.eveningMinute < 0 || s.eveningMinute >= 24 * 60) {
      throw InvalidValueException('eveningMinute', s.eveningMinute);
    }
    if (s.beforeMinutes < 5 || s.beforeMinutes > 24 * 60) {
      throw InvalidValueException('beforeMinutes', s.beforeMinutes);
    }
    if (!isValidBookingUrl(s.bookingUrl)) {
      throw InvalidValueException('bookingUrl', s.bookingUrl);
    }
    if (s.defaultRestSec < 0 || s.defaultRestSec > 3600) {
      throw InvalidValueException('defaultRestSec', s.defaultRestSec);
    }
    if (s.backupReminderDays < 0 || s.backupReminderDays > 365) {
      throw InvalidValueException('backupReminderDays', s.backupReminderDays);
    }
    // 1.6.0: heart rate profile.
    void range(String name, int? v, int min, int max) {
      if (v != null && (v < min || v > max)) {
        throw InvalidValueException(name, v);
      }
    }

    range('hrMax', s.hrMax, 100, 250);
    range('hrThreshold', s.hrThreshold, 80, 230);
    range('birthYear', s.birthYear, 1900, 2100);
    range('hrWarnBpm', s.hrWarnBpm, 60, 250);
    range('hrPauseBpm', s.hrPauseBpm, 40, 220);
  }
}

/// An https address (1.2.0); empty means "no booking page".
bool isValidBookingUrl(String url) {
  final t = url.trim();
  if (t.isEmpty) return true;
  final uri = Uri.tryParse(t);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}
