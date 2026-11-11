import 'package:drift/drift.dart';

import '../../domain/models/models.dart';
import '../db/database.dart';

/// Number of rows per kind of user data.
final class DataCounts {
  const DataCounts({
    required this.exercises,
    required this.plans,
    required this.sessions,
    required this.sets,
    required this.bodyWeights,
  });

  final int exercises;
  final int plans;
  final int sessions;
  final int sets;
  final int bodyWeights;

  bool get isEmpty =>
      exercises == 0 &&
      plans == 0 &&
      sessions == 0 &&
      sets == 0 &&
      bodyWeights == 0;
}

/// Operations on the data as a whole. Each runs in one transaction: on any
/// error nothing is changed.
class MaintenanceRepository {
  MaintenanceRepository(this._db);

  final AppDatabase _db;

  /// Deletes all user data and resets the settings to their defaults.
  Future<void> wipeAll() => _db.transaction(() async {
    await _deleteAllRows();
    await _db.settingsDao.write(AppSettings.defaults);
  });

  /// All user data with ids (for backups and exports).
  Future<Dataset> loadDataset() => _db.transaction(
    () async => Dataset(
      exercises: await _db.select(_db.exercises).get(),
      plans: await _db.select(_db.plans).get(),
      planExercises: await _db.select(_db.planExercises).get(),
      planGroups: await _db.select(_db.planGroups).get(),
      planSchedules: await _db.select(_db.planSchedules).get(),
      sessions: await _db.select(_db.sessions).get(),
      sessionExercises: await _db.select(_db.sessionExercises).get(),
      sessionSupersets: await _db.select(_db.sessionSupersets).get(),
      sets: await _db.select(_db.setEntries).get(),
      bodyWeights: await _db.select(_db.bodyWeightEntries).get(),
      heartRateSamples: await _db.select(_db.heartRateSamples).get(),
    ),
  );

  /// Replaces all user data by [data] (ids are kept). With [settings] the
  /// settings are replaced too; otherwise they are kept except references
  /// to plans that no longer exist.
  Future<void> replaceAll(Dataset data, {AppSettings? settings}) {
    _checkTimes(data);
    return _db.transaction(() async {
      final current = settings ?? await _db.settingsDao.get();
      await _deleteAllRows();
      await _db.batch((b) {
        b.insertAll(_db.exercises, [
          for (final e in data.exercises) e.toInsertable(),
        ]);
        b.insertAll(_db.plans, [for (final p in data.plans) p.toInsertable()]);
        b.insertAll(_db.planSchedules, [
          for (final s in data.planSchedules) s.toInsertable(),
        ]);
        b.insertAll(_db.planGroups, [
          for (final g in data.planGroups) g.toInsertable(),
        ]);
        b.insertAll(_db.planExercises, [
          for (final p in data.planExercises) p.toInsertable(),
        ]);
        b.insertAll(_db.sessions, [
          for (final s in data.sessions) s.toInsertable(),
        ]);
        b.insertAll(_db.sessionSupersets, [
          for (final s in data.sessionSupersets) s.toInsertable(),
        ]);
        b.insertAll(_db.sessionExercises, [
          for (final s in data.sessionExercises) s.toInsertable(),
        ]);
        b.insertAll(_db.setEntries, [
          for (final s in data.sets) s.toInsertable(),
        ]);
        b.insertAll(_db.bodyWeightEntries, [
          for (final w in data.bodyWeights) w.toInsertable(),
        ]);
        b.insertAll(_db.heartRateSamples, [
          for (final h in data.heartRateSamples) h.toInsertable(),
        ]);
      });
      final planId = current.lastSelectedPlanId;
      final keepPlan = planId != null && data.plans.any((p) => p.id == planId);
      await _db.settingsDao.write(
        current.copyWith(lastSelectedPlanId: keepPlan ? planId : null),
      );
    });
  }

  Future<DataCounts> counts() async {
    Future<int> count(TableInfo<Table, Object?> table) async {
      final c = countAll();
      final row = await (_db.selectOnly(table)..addColumns([c])).getSingle();
      return row.read(c)!;
    }

    return DataCounts(
      exercises: await count(_db.exercises),
      plans: await count(_db.plans),
      sessions: await count(_db.sessions),
      sets: await count(_db.setEntries),
      bodyWeights: await count(_db.bodyWeightEntries),
    );
  }

  Future<void> _deleteAllRows() async {
    // Children first, so no foreign key is ever violated.
    await _db.delete(_db.heartRateSamples).go();
    await _db.delete(_db.setEntries).go();
    await _db.delete(_db.sessionExercises).go();
    await _db.delete(_db.sessionSupersets).go();
    await _db.delete(_db.sessions).go();
    await _db.delete(_db.planExercises).go();
    await _db.delete(_db.planGroups).go();
    await _db.delete(_db.planSchedules).go();
    await _db.settingsDao.write(
      (await _db.settingsDao.get()).copyWith(lastSelectedPlanId: null),
    );
    await _db.delete(_db.plans).go();
    await _db.delete(_db.exercises).go();
    await _db.delete(_db.bodyWeightEntries).go();
  }

  /// All times must already be normalized (UTC, millisecond precision).
  static void _checkTimes(Dataset data) {
    void check(DateTime? t, String what) {
      if (t != null && (!t.isUtc || t.microsecond != 0)) {
        throw ArgumentError.value(t, what, 'must be UTC with ms precision');
      }
    }

    for (final e in data.exercises) {
      check(e.createdAt, 'exercise.createdAt');
    }
    for (final p in data.plans) {
      check(p.createdAt, 'plan.createdAt');
    }
    for (final s in data.sessions) {
      check(s.startedAt, 'session.startedAt');
      check(s.endedAt, 'session.endedAt');
    }
    for (final s in data.sessionExercises) {
      check(s.completedAt, 'sessionExercise.completedAt');
    }
    for (final s in data.sets) {
      check(s.completedAt, 'set.completedAt');
    }
    for (final w in data.bodyWeights) {
      check(w.createdAt, 'bodyWeight.createdAt');
    }
    for (final h in data.heartRateSamples) {
      check(h.recordedAt, 'heartRateSample.recordedAt');
    }
  }
}
