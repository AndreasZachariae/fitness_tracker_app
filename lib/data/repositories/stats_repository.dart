import '../../domain/statistics.dart';
import '../db/database.dart';

/// Loads everything the statistics need (SPEC §6.5). Calculations happen
/// in `domain/statistics.dart`.
class StatsRepository {
  StatsRepository(this._db);

  final AppDatabase _db;

  Stream<StatsData> watch() =>
      _db.sessionsDao.watchStatsChanges().asyncMap((_) => load());

  Future<StatsData> load() async {
    final sessions = await _db.sessionsDao.finishedWithDetails();
    final weights = await _db.bodyWeightDao.getAllAscending();
    return StatsData(
      trainings: [
        for (final (session, details) in sessions)
          Training(session: session, exercises: details),
      ],
      bodyWeights: weights,
      exercises: await _db.exercisesDao.getAll(),
      heartRates: {
        for (final h in await _db.select(_db.sessionHeartRates).get())
          h.sessionId: h,
      },
    );
  }
}
