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
    if (s.defaultRestSec < 0 || s.defaultRestSec > 3600) {
      throw InvalidValueException('defaultRestSec', s.defaultRestSec);
    }
    if (s.backupReminderDays < 0 || s.backupReminderDays > 365) {
      throw InvalidValueException('backupReminderDays', s.backupReminderDays);
    }
  }
}
