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

  /// Buffers values of the running training (1.5.1: every value, written
  /// in small batches). Ignored once the training has ended: its summary is
  /// already made. Returns whether they were stored.
  Future<bool> addSamples(
    int sessionId,
    List<({DateTime at, int bpm})> values,
  ) => _db.transaction(() async {
    for (final v in values) {
      if (v.bpm < minBpm || v.bpm > maxBpm) {
        throw InvalidValueException('bpm', v.bpm);
      }
    }
    final session = await _db.sessionsDao.findById(sessionId);
    if (session == null || !session.isActive || values.isEmpty) return false;
    await _db.batch(
      (b) => b.insertAll(_db.heartRateSamples, [
        for (final v in values)
          HeartRateSamplesCompanion.insert(
            sessionId: sessionId,
            recordedAt: storageTime(v.at),
            bpm: v.bpm,
          ),
      ]),
    );
    return true;
  });

  /// What is kept of a finished training (1.5.1).
  Stream<SessionHeartRate?> watchSummary(int sessionId) => (_db.select(
    _db.sessionHeartRates,
  )..where((h) => h.sessionId.equals(sessionId))).watchSingleOrNull();

  /// Summaries of the finished trainings before [sessionId]: of the same
  /// plan, or of all trainings when the plan has none (violin comparison).
  Future<List<SessionHeartRate>> earlierSummaries(int sessionId) async {
    final session = await _db.sessionsDao.findById(sessionId);
    if (session == null) return const [];
    Future<List<SessionHeartRate>> query({required bool samePlan}) async {
      final q =
          _db.select(_db.sessionHeartRates).join([
            innerJoin(
              _db.sessions,
              _db.sessions.id.equalsExp(_db.sessionHeartRates.sessionId),
            ),
          ])..where(
            _db.sessions.startedAt.isSmallerThanValue(session.startedAt) &
                _db.sessions.endedAt.isNotNull(),
          );
      if (samePlan) {
        final planId = session.planId;
        if (planId == null) return const [];
        q.where(_db.sessions.planId.equals(planId));
      }
      return [
        for (final row in await q.get()) row.readTable(_db.sessionHeartRates),
      ];
    }

    final same = await query(samePlan: true);
    return same.isNotEmpty ? same : query(samePlan: false);
  }

  /// All kept summaries (statistics).
  Future<List<SessionHeartRate>> allSummaries() =>
      _db.select(_db.sessionHeartRates).get();

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
