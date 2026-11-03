import 'package:drift/drift.dart';

import '../../../domain/models/models.dart';
import '../database.dart';
import '../tables.dart';

part 'sessions_dao.g.dart';

@DriftAccessor(tables: [Sessions, SessionExercises, SetEntries, Exercises])
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

  Future<SessionExercise?> findSessionExercise(int id) => (select(
    sessionExercises,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Exercises of a session in order, each with its exercise and sets.
  Stream<List<SessionExerciseDetail>> watchDetails(int sessionId) {
    final query =
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
    return query.watch().map(_groupDetails);
  }

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
}
