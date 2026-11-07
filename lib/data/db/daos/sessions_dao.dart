import 'package:drift/drift.dart';

import '../../../domain/models/models.dart';
import '../../../domain/weight_steps.dart';
import '../database.dart';
import '../tables.dart';

part 'sessions_dao.g.dart';

@DriftAccessor(
  tables: [Sessions, SessionExercises, SessionSupersets, SetEntries, Exercises],
)
class SessionsDao extends DatabaseAccessor<AppDatabase>
    with _$SessionsDaoMixin {
  SessionsDao(super.attachedDatabase);

  SimpleSelectStatement<$SessionsTable, Session> _active() =>
      select(sessions)..where((s) => s.endedAt.isNull());

  Stream<Session?> watchActive() => _active().watchSingleOrNull();

  Future<Session?> getActive() => _active().getSingleOrNull();

  Future<Session?> findById(int id) =>
      (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// Finished sessions, newest first.
  Stream<List<Session>> watchFinished() =>
      (select(sessions)
            ..where((s) => s.endedAt.isNotNull())
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
          .watch();

  Future<int> insertSession(SessionsCompanion row) =>
      into(sessions).insert(row);

  Future<void> updateSession(Session session) =>
      update(sessions).replace(session.toInsertable());

  Future<int> deleteById(int id) =>
      (delete(sessions)..where((s) => s.id.equals(id))).go();

  Future<int> insertSessionExercise(SessionExercisesCompanion row) =>
      into(sessionExercises).insert(row);

  /// Exercises of a session in order.
  Future<List<SessionExercise>> getSessionExercises(int sessionId) =>
      (select(sessionExercises)
            ..where((e) => e.sessionId.equals(sessionId))
            ..orderBy([
              (e) => OrderingTerm.asc(e.position),
              (e) => OrderingTerm.asc(e.id),
            ]))
          .get();

  Future<void> updateSessionExercise(SessionExercise e) =>
      update(sessionExercises).replace(e.toInsertable());

  Future<int> nextSessionExercisePosition(int sessionId) async {
    final max = sessionExercises.position.max();
    final row =
        await (selectOnly(sessionExercises)
              ..addColumns([max])
              ..where(sessionExercises.sessionId.equals(sessionId)))
            .getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  /// Sets of one session exercise, ordered by index.
  Future<List<SetEntry>> getSets(int sessionExerciseId) =>
      (select(setEntries)
            ..where((s) => s.sessionExerciseId.equals(sessionExerciseId))
            ..orderBy([(s) => OrderingTerm.asc(s.setIndex)]))
          .get();

  Future<void> updateSet(SetEntry set) =>
      update(setEntries).replace(set.toInsertable());

  /// All sets of an exercise with their session, in chronological order.
  Future<List<({SetEntry set, int sessionId})>> historySets(
    int exerciseId,
  ) async {
    final query =
        select(setEntries).join([
            innerJoin(
              sessionExercises,
              sessionExercises.id.equalsExp(setEntries.sessionExerciseId),
            ),
          ])
          ..where(sessionExercises.exerciseId.equals(exerciseId))
          ..orderBy([
            OrderingTerm.asc(setEntries.completedAt),
            OrderingTerm.asc(setEntries.id),
          ]);
    return [
      for (final row in await query.get())
        (
          set: row.readTable(setEntries),
          sessionId: row.readTable(sessionExercises).sessionId,
        ),
    ];
  }

  Stream<Session?> watchById(int id) =>
      (select(sessions)..where((s) => s.id.equals(id))).watchSingleOrNull();

  /// Every set with its session and exercise type, chronologically;
  /// [storesKg] is false for levels without kg (1.1.0).
  Future<
    List<
      ({
        SetEntry set,
        int sessionId,
        int exerciseId,
        ExerciseType type,
        bool storesKg,
      })
    >
  >
  allSetsWithContext() async {
    final query =
        select(setEntries).join([
          innerJoin(
            sessionExercises,
            sessionExercises.id.equalsExp(setEntries.sessionExerciseId),
          ),
          innerJoin(
            exercises,
            exercises.id.equalsExp(sessionExercises.exerciseId),
          ),
        ])..orderBy([
          OrderingTerm.asc(setEntries.completedAt),
          OrderingTerm.asc(setEntries.id),
        ]);
    return [
      for (final row in await query.get())
        (
          set: row.readTable(setEntries),
          sessionId: row.readTable(sessionExercises).sessionId,
          exerciseId: row.readTable(sessionExercises).exerciseId,
          type: row.readTable(exercises).type,
          storesKg: storesKg(row.readTable(exercises)),
        ),
    ];
  }

  /// All finished sessions with exercises and sets, oldest first.
  Future<List<(Session, List<SessionExerciseDetail>)>>
  finishedWithDetails() async {
    final query =
        select(sessionExercises).join([
            innerJoin(
              sessions,
              sessions.id.equalsExp(sessionExercises.sessionId),
            ),
            innerJoin(
              exercises,
              exercises.id.equalsExp(sessionExercises.exerciseId),
            ),
            leftOuterJoin(
              setEntries,
              setEntries.sessionExerciseId.equalsExp(sessionExercises.id),
            ),
          ])
          ..where(sessions.endedAt.isNotNull())
          ..orderBy([
            OrderingTerm.asc(sessions.startedAt),
            OrderingTerm.asc(sessions.id),
            OrderingTerm.asc(sessionExercises.position),
            OrderingTerm.asc(sessionExercises.id),
            OrderingTerm.asc(setEntries.setIndex),
          ]);
    final rows = await query.get();
    final result = <(Session, List<SessionExerciseDetail>)>[];
    final buffer = <TypedResult>[];
    void flush() {
      if (buffer.isEmpty) return;
      result.add((buffer.first.readTable(sessions), _groupDetails(buffer)));
      buffer.clear();
    }

    for (final row in rows) {
      if (buffer.isNotEmpty &&
          buffer.first.readTable(sessions).id != row.readTable(sessions).id) {
        flush();
      }
      buffer.add(row);
    }
    flush();
    return result;
  }

  Future<List<Session>> finishedSessions() =>
      (select(sessions)
            ..where((s) => s.endedAt.isNotNull())
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
          .get();

  Future<int> deleteSessionExercise(int id) =>
      (delete(sessionExercises)..where((e) => e.id.equals(id))).go();

  /// Emits whenever training data or body weights change.
  Stream<void> watchStatsChanges() => customSelect(
    'SELECT 1',
    readsFrom: {
      setEntries,
      sessionExercises,
      sessions,
      exercises,
      attachedDatabase.bodyWeightEntries,
    },
  ).watch().map((_) {});

  /// Emits whenever sets, session exercises or sessions change.
  Stream<void> watchSetChanges() => customSelect(
    'SELECT 1',
    readsFrom: {setEntries, sessionExercises, sessions, exercises},
  ).watch().map((_) {});

  /// Time of the latest set of a session, if any.
  Future<DateTime?> lastSetTime(int sessionId) async {
    final max = setEntries.completedAt.max();
    final query =
        selectOnly(setEntries).join([
            innerJoin(
              sessionExercises,
              sessionExercises.id.equalsExp(setEntries.sessionExerciseId),
              useColumns: false,
            ),
          ])
          ..addColumns([max])
          ..where(sessionExercises.sessionId.equals(sessionId));
    return (await query.getSingle()).read(max);
  }

  /// The finished session of [planId] started right before [before].
  Future<Session?> previousPlanSession(int planId, DateTime before) =>
      (select(sessions)
            ..where(
              (s) =>
                  s.planId.equals(planId) &
                  s.endedAt.isNotNull() &
                  s.startedAt.isSmallerThanValue(before),
            )
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<SessionExercise?> findSessionExercise(int id) => (select(
    sessionExercises,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  JoinedSelectStatement<HasResultSet, dynamic> _detailsQuery(int sessionId) =>
      select(sessionExercises).join([
          innerJoin(
            exercises,
            exercises.id.equalsExp(sessionExercises.exerciseId),
          ),
          leftOuterJoin(
            setEntries,
            setEntries.sessionExerciseId.equalsExp(sessionExercises.id),
          ),
        ])
        ..where(sessionExercises.sessionId.equals(sessionId))
        ..orderBy([
          OrderingTerm.asc(sessionExercises.position),
          OrderingTerm.asc(sessionExercises.id),
          OrderingTerm.asc(setEntries.setIndex),
        ]);

  /// Exercises of a session in order, each with its exercise and sets.
  Stream<List<SessionExerciseDetail>> watchDetails(int sessionId) =>
      _detailsQuery(sessionId).watch().map(_groupDetails);

  Future<List<SessionExerciseDetail>> getDetails(int sessionId) async =>
      _groupDetails(await _detailsQuery(sessionId).get());

  List<SessionExerciseDetail> _groupDetails(List<TypedResult> rows) {
    final result = <SessionExerciseDetail>[];
    for (final row in rows) {
      final sessionExercise = row.readTable(sessionExercises);
      if (result.isEmpty ||
          result.last.sessionExercise.id != sessionExercise.id) {
        result.add(
          SessionExerciseDetail(
            sessionExercise: sessionExercise,
            exercise: row.readTable(exercises),
            sets: [],
          ),
        );
      }
      final set = row.readTableOrNull(setEntries);
      if (set != null) result.last.sets.add(set);
    }
    return [
      for (final d in result)
        SessionExerciseDetail(
          sessionExercise: d.sessionExercise,
          exercise: d.exercise,
          sets: List.unmodifiable(d.sets),
        ),
    ];
  }

  /// For every exercise: its working sets in the latest finished session
  /// in which it has at least one working set.
  Stream<Map<int, LastPerformance>> watchLastPerformances() {
    final query = customSelect(
      'SELECT se.exercise_id AS exercise_id, s.started_at AS started_at, '
      'x.id AS set_id '
      'FROM set_entries x '
      'JOIN session_exercises se ON se.id = x.session_exercise_id '
      'JOIN sessions s ON s.id = se.session_id '
      'WHERE s.ended_at IS NOT NULL AND x.is_warmup = 0 '
      'ORDER BY s.started_at DESC, se.id, x.set_index',
      readsFrom: {sessions, sessionExercises, setEntries},
    );
    return query.watch().asyncMap((rows) async {
      // Latest session per exercise; collect only that session's sets.
      final latest = <int, String>{};
      final setIds = <int>[];
      for (final row in rows) {
        final exerciseId = row.read<int>('exercise_id');
        final startedAt = row.read<String>('started_at');
        final known = latest.putIfAbsent(exerciseId, () => startedAt);
        if (known == startedAt) setIds.add(row.read<int>('set_id'));
      }
      if (setIds.isEmpty) return <int, LastPerformance>{};
      final sets = await (select(
        setEntries,
      )..where((x) => x.id.isIn(setIds))).get();
      final seIds = {for (final s in sets) s.sessionExerciseId};
      final ses = await (select(
        sessionExercises,
      )..where((e) => e.id.isIn(seIds))).get();
      final exerciseOf = {for (final e in ses) e.id: e.exerciseId};
      final byExercise = <int, List<SetEntry>>{};
      for (final s in sets) {
        byExercise
            .putIfAbsent(exerciseOf[s.sessionExerciseId]!, () => [])
            .add(s);
      }
      return {
        for (final MapEntry(key: exerciseId, value: list) in byExercise.entries)
          exerciseId: LastPerformance(
            exerciseId: exerciseId,
            sessionStartedAt: DateTime.parse(latest[exerciseId]!),
            sets: List.unmodifiable(
              list..sort((a, b) => a.setIndex.compareTo(b.setIndex)),
            ),
          ),
      };
    });
  }

  /// Exercise ids ordered by their most recent session, newest first.
  Stream<List<int>> watchRecentExerciseIds({int limit = 6}) {
    return customSelect(
      'SELECT se.exercise_id AS exercise_id, MAX(s.started_at) AS last '
      'FROM session_exercises se JOIN sessions s ON s.id = se.session_id '
      'GROUP BY se.exercise_id ORDER BY last DESC LIMIT ?',
      variables: [Variable.withInt(limit)],
      readsFrom: {sessions, sessionExercises},
    ).watch().map((rows) => [for (final r in rows) r.read<int>('exercise_id')]);
  }

  Future<int> nextSetIndex(int sessionExerciseId) async {
    final max = setEntries.setIndex.max();
    final row =
        await (selectOnly(setEntries)
              ..addColumns([max])
              ..where(setEntries.sessionExerciseId.equals(sessionExerciseId)))
            .getSingle();
    return (row.read(max) ?? 0) + 1;
  }

  Future<SetEntry> insertSet(SetEntriesCompanion row) =>
      into(setEntries).insertReturning(row);

  Future<SetEntry?> findSet(int id) =>
      (select(setEntries)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> deleteSet(int id) =>
      (delete(setEntries)..where((s) => s.id.equals(id))).go();

  // Supersets (M9)

  SimpleSelectStatement<$SessionSupersetsTable, SessionSuperset> _supersets(
    int sessionId,
  ) => select(sessionSupersets)..where((x) => x.sessionId.equals(sessionId));

  Stream<List<SessionSuperset>> watchSupersets(int sessionId) =>
      _supersets(sessionId).watch();

  Future<List<SessionSuperset>> getSupersets(int sessionId) =>
      _supersets(sessionId).get();

  Future<SessionSuperset?> findSuperset(int id) => (select(
    sessionSupersets,
  )..where((x) => x.id.equals(id))).getSingleOrNull();

  Future<int> insertSuperset(SessionSupersetsCompanion row) =>
      into(sessionSupersets).insert(row);

  Future<void> updateSuperset(SessionSuperset superset) =>
      update(sessionSupersets).replace(superset.toInsertable());

  Future<int> deleteSuperset(int id) =>
      (delete(sessionSupersets)..where((x) => x.id.equals(id))).go();
}
