import '../../core/clock.dart';
import '../../domain/models/models.dart';
import '../db/database.dart';
import '../db/storage_time.dart';
import 'repository_exceptions.dart';

/// Body weight entries, one per local day.
class BodyWeightRepository {
  BodyWeightRepository(this._db, this._clock);

  /// Plausible range in kg.
  static const minKg = 20.0;
  static const maxKg = 400.0;

  final AppDatabase _db;
  final Clock _clock;

  /// All entries, newest day first.
  Stream<List<BodyWeightEntry>> watchAll() => _db.bodyWeightDao.watchAll();

  Future<BodyWeightEntry?> findByDate(LocalDate date) =>
      _db.bodyWeightDao.findByDate(date);

  /// Saves the weight of [date], overwriting an existing entry of that day.
  /// The weight is rounded to one decimal; future days are rejected.
  Future<BodyWeightEntry> save(LocalDate date, double weightKg) =>
      _db.transaction(() async {
        if (!weightKg.isFinite || weightKg < minKg || weightKg > maxKg) {
          throw InvalidValueException('weightKg', weightKg);
        }
        if (date.isAfter(LocalDate.fromDateTime(_clock.now()))) {
          throw InvalidValueException('date', date);
        }
        final rounded = (weightKg * 10).round() / 10;
        final existing = await _db.bodyWeightDao.findByDate(date);
        if (existing != null) {
          final updated = BodyWeightEntry(
            id: existing.id,
            date: date,
            weightKg: rounded,
            createdAt: existing.createdAt,
          );
          await _db.bodyWeightDao.updateEntry(updated);
          return updated;
        }
        final id = await _db.bodyWeightDao.insertEntry(
          BodyWeightEntriesCompanion.insert(
            date: date,
            weightKg: rounded,
            createdAt: storageTime(_clock.now()),
          ),
        );
        return (await _db.bodyWeightDao.findById(id))!;
      });

  Future<void> delete(int id) => _db.transaction(() async {
    if (await _db.bodyWeightDao.findById(id) == null) {
      throw NotFoundException('bodyWeight', id);
    }
    await _db.bodyWeightDao.deleteById(id);
  });
}
