import 'package:drift/drift.dart' show Value;

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

  /// Plausible ranges of the smart scale values (1.7.0).
  static const minPct = 1.0;
  static const maxPct = 99.0;
  static const minBoneKg = 0.1;
  static const maxBoneKg = 20.0;

  static double _round1(double v) => (v * 10).round() / 10;

  static double? _checked(String field, double? v, double min, double max) {
    if (v == null) return null;
    if (!v.isFinite || v < min || v > max) {
      throw InvalidValueException(field, v);
    }
    return _round1(v);
  }

  /// Saves the weight of [date], overwriting an existing entry of that day.
  /// All values are rounded to one decimal; future days are rejected.
  /// [composition] (1.7.0): the values of a smart scale; `null` keeps those
  /// already stored for the day.
  Future<BodyWeightEntry> save(
    LocalDate date,
    double weightKg, {
    BodyComposition? composition,
  }) => _db.transaction(() async {
    if (!weightKg.isFinite || weightKg < minKg || weightKg > maxKg) {
      throw InvalidValueException('weightKg', weightKg);
    }
    if (date.isAfter(LocalDate.fromDateTime(_clock.now()))) {
      throw InvalidValueException('date', date);
    }
    final existing = await _db.bodyWeightDao.findByDate(date);
    final c = composition ?? existing?.composition ?? noComposition;
    final entry = BodyWeightEntry(
      id: existing?.id ?? 0,
      date: date,
      weightKg: _round1(weightKg),
      createdAt: existing?.createdAt ?? storageTime(_clock.now()),
      musclePct: _checked('musclePct', c.musclePct, minPct, maxPct),
      fatPct: _checked('fatPct', c.fatPct, minPct, maxPct),
      waterPct: _checked('waterPct', c.waterPct, minPct, maxPct),
      boneKg: _checked('boneKg', c.boneKg, minBoneKg, maxBoneKg),
    );
    if (existing != null) {
      await _db.bodyWeightDao.updateEntry(entry);
      return entry;
    }
    final id = await _db.bodyWeightDao.insertEntry(
      BodyWeightEntriesCompanion.insert(
        date: date,
        weightKg: entry.weightKg,
        createdAt: entry.createdAt,
        musclePct: Value(entry.musclePct),
        fatPct: Value(entry.fatPct),
        waterPct: Value(entry.waterPct),
        boneKg: Value(entry.boneKg),
      ),
    );
    return (await _db.bodyWeightDao.findById(id))!;
  });

  /// Puts a deleted entry back with its id ("Rückgängig").
  Future<void> restore(BodyWeightEntry entry) => _db.transaction(() async {
    if (await _db.bodyWeightDao.findByDate(entry.date) != null) {
      throw InvalidValueException('date', entry.date);
    }
    await _db.into(_db.bodyWeightEntries).insert(entry.toInsertable());
  });

  Future<void> delete(int id) => _db.transaction(() async {
    if (await _db.bodyWeightDao.findById(id) == null) {
      throw NotFoundException('bodyWeight', id);
    }
    await _db.bodyWeightDao.deleteById(id);
  });
}
