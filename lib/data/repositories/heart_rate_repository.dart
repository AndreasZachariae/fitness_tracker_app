import 'package:drift/drift.dart';

import '../../domain/heart_rate.dart';
import '../../domain/models/models.dart';
import '../db/database.dart';
import '../db/storage_time.dart';
import 'repository_exceptions.dart';

/// Heart rate of trainings (1.5.0). Samples go with their session: deleting
/// a training deletes them too (foreign key with cascade).
class HeartRateRepository {
  HeartRateRepository(this._db);

  final AppDatabase _db;

  /// Stores one value at once (like a set: nothing waits for the end).
  Future<void> addSample(int sessionId, DateTime at, int bpm) async {
    if (bpm < minBpm || bpm > maxBpm) {
      throw InvalidValueException('bpm', bpm);
    }
    await _db
        .into(_db.heartRateSamples)
        .insert(
          HeartRateSamplesCompanion.insert(
            sessionId: sessionId,
            recordedAt: storageTime(at),
            bpm: bpm,
          ),
        );
  }

  Stream<List<HeartRateSample>> watchSamples(int sessionId) =>
      (_db.select(_db.heartRateSamples)
            ..where((h) => h.sessionId.equals(sessionId))
            ..orderBy([(h) => OrderingTerm.asc(h.recordedAt)]))
          .watch();

  Future<List<HeartRateSample>> getSamples(int sessionId) =>
      (_db.select(_db.heartRateSamples)
            ..where((h) => h.sessionId.equals(sessionId))
            ..orderBy([(h) => OrderingTerm.asc(h.recordedAt)]))
          .get();
}
