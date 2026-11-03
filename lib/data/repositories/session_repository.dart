import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../domain/history.dart';
import '../../domain/models/models.dart';
import '../../domain/records.dart';
import '../../domain/session_rules.dart';
import '../../domain/set_validation.dart';
import '../db/database.dart';
import '../db/storage_time.dart';
import 'repository_exceptions.dart';

/// A record set in a session, for the summary (SPEC §6.3, §7.7).
final class SessionRecord {
  const SessionRecord({
    required this.exercise,
    required this.kind,
    required this.value,
  });

  final Exercise exercise;
  final RecordKind kind;
  final double value;
}

/// Result of [SessionRepository.saveSet], needed for "Rückgängig".
final class SetSaved {
  const SetSaved({
    required this.set,
    required this.previousStatuses,
    required this.completedExercise,
    this.records = const [],
  });

  final SetEntry set;

  /// Records set by this set (empty in the first session of the exercise).
  final List<RecordKind> records;

  /// Status and completion time of every exercise of the session before
  /// the set was saved.
  final Map<int, (SessionExerciseStatus, DateTime?)> previousStatuses;

  /// Whether this set reached the target and finished the exercise.
  final bool completedExercise;
}

/// Training sessions and their sets.
///
/// Every set is written to the database immediately (CLAUDE.md, rule 5).
class SessionRepository {
  SessionRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// The running session, if any.
  Stream<Session?> watchActive() => _db.sessionsDao.watchActive();

  Future<Session?> getActive() => _db.sessionsDao.getActive();

  Future<Session?> findById(int id) => _db.sessionsDao.findById(id);

  /// Finished sessions, newest first.
  Stream<List<Session>> watchFinished() => _db.sessionsDao.watchFinished();

  /// Last finished performance per exercise id ("Zuletzt: …").
  Stream<Map<int, LastPerformance>> watchLastPerformances() =>
      _db.sessionsDao.watchLastPerformances();

  /// Exercises of a session in order, with their sets.
  Stream<List<SessionExerciseDetail>> watchDetails(int sessionId) =>
      _db.sessionsDao.watchDetails(sessionId);

  /// Starts a session from [plan] (`null` = free training) with the given
  /// exercises; the first one becomes active. Returns the session id.
  ///
  /// Throws [ActiveSessionExistsException] if a session is running.
  Future<int> start({
    Plan? plan,
    required List<SessionExerciseDraft> exercises,
  }) => _db.transaction(() async {
    final active = await _db.sessionsDao.getActive();
    if (active != null) throw ActiveSessionExistsException(active.id);

    final seen = <int>{};
    for (final draft in exercises) {
      if (!seen.add(draft.exerciseId)) {
        throw DuplicateExerciseException(draft.exerciseId);
      }
      if (await _db.exercisesDao.findById(draft.exerciseId) == null) {
        throw NotFoundException('exercise', draft.exerciseId);
      }
      if (draft.targetSets < 1) {
        throw InvalidValueException('targetSets', draft.targetSets);
      }
    }

    final sessionId = await _db.sessionsDao.insertSession(
      SessionsCompanion.insert(
        planId: Value(plan?.id),
        planNameSnapshot: Value(plan?.name),
        startedAt: storageTime(_clock.now()),
      ),
    );
    for (var i = 0; i < exercises.length; i++) {
      final draft = exercises[i];
      await _db.sessionsDao.insertSessionExercise(
        SessionExercisesCompanion.insert(
          sessionId: sessionId,
          exerciseId: draft.exerciseId,
          position: i,
          targetSets: draft.targetSets,
          targetReps: Value(draft.targetReps),
          targetDurationSec: Value(draft.targetDurationSec),
          restSec: Value(draft.restSec),
          status: i == 0
              ? SessionExerciseStatus.active
              : SessionExerciseStatus.pending,
        ),
      );
    }
    return sessionId;
  });

  /// Records a set for a session exercise of the running session.
  ///
  /// Only the fields that belong to the exercise type are stored
  /// (`bodyweight` without weight stores 0 kg added weight).
  Future<SetEntry> addSet(
    int sessionExerciseId, {
    double? weightKg,
    int? reps,
    int? durationSec,
  }) => _db.transaction(() async {
    final sessionExercise = await _db.sessionsDao.findSessionExercise(
      sessionExerciseId,
    );
    if (sessionExercise == null) {
      throw NotFoundException('sessionExercise', sessionExerciseId);
    }
    final session = await _db.sessionsDao.findById(sessionExercise.sessionId);
    if (session == null || !session.isActive) {
      throw SessionNotActiveException(sessionExercise.sessionId);
    }
    final exercise = await _db.exercisesDao.findById(
      sessionExercise.exerciseId,
    );
    if (exercise == null) {
      throw NotFoundException('exercise', sessionExercise.exerciseId);
    }

    final error = validateSet(
      exercise.type,
      weightKg: weightKg,
      reps: reps,
      durationSec: durationSec,
    );
    if (error != null) throw InvalidSetException(error);

    final (weight, storedReps, duration) = _fieldsFor(
      exercise.type,
      SetValues(weightKg: weightKg, reps: reps, durationSec: durationSec),
    );

    return _db.sessionsDao.insertSet(
      SetEntriesCompanion.insert(
        sessionExerciseId: sessionExerciseId,
        setIndex: await _db.sessionsDao.nextSetIndex(sessionExerciseId),
        weightKg: Value(weight),
        reps: Value(storedReps),
        durationSec: Value(duration),
        completedAt: storageTime(_clock.now()),
      ),
    );
  });

  /// Saves a set of the active exercise (SPEC §6.2 "Satz speichern"):
  /// stored at once; reaching the target sets marks the exercise done and,
  /// with `autoActivateNext`, activates the next open exercise.
  Future<SetSaved> saveSet(int sessionExerciseId, SetValues values) =>
      _db.transaction(() async {
        final before = await _exercisesOfSessionOf(sessionExerciseId);
        final set = await addSet(
          sessionExerciseId,
          weightKg: values.weightKg,
          reps: values.reps,
          durationSec: values.durationSec,
        );
        final se = (await _db.sessionsDao.findSessionExercise(
          sessionExerciseId,
        ))!;
        final count = (await _db.sessionsDao.getSets(sessionExerciseId))
            .where((s) => !s.isWarmup)
            .length;
        var completed = false;
        if (count >= se.targetSets) {
          await _db.sessionsDao.updateSessionExercise(
            se.copyWith(
              status: SessionExerciseStatus.done,
              completedAt: set.completedAt,
            ),
          );
          completed = true;
          await _autoActivateNext(se);
        } else if (se.status != SessionExerciseStatus.active) {
          await _activate(se);
        }
        final exercise = (await _db.exercisesDao.findById(se.exerciseId))!;
        final records = await _recordsOfExercise(exercise);
        return SetSaved(
          set: set,
          previousStatuses: {
            for (final e in before) e.id: (e.status, e.completedAt),
          },
          completedExercise: completed,
          records: records[set.id] ?? const [],
        );
      });

  /// Undoes [saved]: deletes the set and restores all exercise statuses.
  Future<void> undoSave(SetSaved saved) => _db.transaction(() async {
    if (await _db.sessionsDao.findSet(saved.set.id) != null) {
      await deleteSet(saved.set.id);
    }
    for (final MapEntry(key: id, value: (status, completedAt))
        in saved.previousStatuses.entries) {
      final e = await _db.sessionsDao.findSessionExercise(id);
      if (e == null) continue;
      if (e.status != status || e.completedAt != completedAt) {
        await _db.sessionsDao.updateSessionExercise(
          e.copyWith(status: status, completedAt: completedAt),
        );
      }
    }
  });

  /// Makes an exercise the active one; the previously active one becomes
  /// open and keeps its sets. Also reopens done/skipped exercises.
  Future<void> activate(int sessionExerciseId) => _db.transaction(() async {
    final se = await _requireInActiveSession(sessionExerciseId);
    await _activate(se);
  });

  /// "Überspringen": the exercise is marked skipped (its sets stay).
  Future<void> skip(int sessionExerciseId) => _db.transaction(() async {
    final se = await _requireInActiveSession(sessionExerciseId);
    await _db.sessionsDao.updateSessionExercise(
      se.copyWith(
        status: SessionExerciseStatus.skipped,
        completedAt: storageTime(_clock.now()),
      ),
    );
    await _autoActivateNext(se);
  });

  /// "Übung beenden" (needs at least one set).
  Future<void> finishExercise(int sessionExerciseId) =>
      _db.transaction(() async {
        final se = await _requireInActiveSession(sessionExerciseId);
        final sets = await _db.sessionsDao.getSets(sessionExerciseId);
        if (sets.isEmpty) {
          throw const InvalidValueException('sets', 0);
        }
        await _db.sessionsDao.updateSessionExercise(
          se.copyWith(
            status: SessionExerciseStatus.done,
            completedAt: sets.last.completedAt,
          ),
        );
        await _autoActivateNext(se);
      });

  /// "+1 Satz": one more target set.
  Future<void> addTargetSet(int sessionExerciseId) => _db.transaction(() async {
    final se = await _requireInActiveSession(sessionExerciseId);
    await _db.sessionsDao.updateSessionExercise(
      se.copyWith(targetSets: se.targetSets + 1),
    );
  });

  /// Adds an exercise to the running session only (not to the plan).
  Future<int> addExerciseToSession(
    int sessionId,
    int exerciseId,
    ExerciseTargets targets,
  ) => _db.transaction(() async {
    final session = await _db.sessionsDao.findById(sessionId);
    if (session == null) throw NotFoundException('session', sessionId);
    if (!session.isActive) throw SessionNotActiveException(sessionId);
    if (await _db.exercisesDao.findById(exerciseId) == null) {
      throw NotFoundException('exercise', exerciseId);
    }
    final existing = await _db.sessionsDao.getSessionExercises(sessionId);
    if (existing.any((e) => e.exerciseId == exerciseId)) {
      throw DuplicateExerciseException(exerciseId);
    }
    if (targets.sets < 1) {
      throw InvalidValueException('targetSets', targets.sets);
    }
    return _db.sessionsDao.insertSessionExercise(
      SessionExercisesCompanion.insert(
        sessionId: sessionId,
        exerciseId: exerciseId,
        position: await _db.sessionsDao.nextSessionExercisePosition(sessionId),
        targetSets: targets.sets,
        targetReps: Value(targets.reps),
        targetDurationSec: Value(targets.durationSec),
        restSec: Value(targets.restSec),
        status: SessionExerciseStatus.pending,
      ),
    );
  });

  /// New order of a session's exercises. Done and skipped exercises must
  /// keep their places (SPEC §6.2).
  Future<void> reorderSession(int sessionId, List<int> sessionExerciseIds) =>
      _db.transaction(() async {
        final current = await _db.sessionsDao.getSessionExercises(sessionId);
        final valid =
            sessionExerciseIds.length == current.length &&
            sessionExerciseIds.toSet().containsAll(current.map((e) => e.id)) &&
            [
              for (final (i, e) in current.indexed)
                if (!isMovable(e.status)) sessionExerciseIds[i] == e.id,
            ].every((ok) => ok);
        if (!valid) {
          throw InvalidValueException('sessionExerciseIds', sessionExerciseIds);
        }
        final byId = {for (final e in current) e.id: e};
        for (final (i, id) in sessionExerciseIds.indexed) {
          final e = byId[id]!;
          if (e.position != i) {
            await _db.sessionsDao.updateSessionExercise(
              e.copyWith(position: i),
            );
          }
        }
      });

  /// Changes the values of a stored set (also in finished sessions).
  Future<void> updateSet(int setId, SetValues values) =>
      _db.transaction(() async {
        final set = await _db.sessionsDao.findSet(setId);
        if (set == null) throw NotFoundException('set', setId);
        final se = (await _db.sessionsDao.findSessionExercise(
          set.sessionExerciseId,
        ))!;
        final exercise = (await _db.exercisesDao.findById(se.exerciseId))!;
        final error = validateSet(
          exercise.type,
          weightKg: values.weightKg,
          reps: values.reps,
          durationSec: values.durationSec,
        );
        if (error != null) throw InvalidSetException(error);
        final (weight, reps, duration) = _fieldsFor(exercise.type, values);
        await _db.sessionsDao.updateSet(
          SetEntry(
            id: set.id,
            sessionExerciseId: set.sessionExerciseId,
            setIndex: set.setIndex,
            weightKg: weight,
            reps: reps,
            durationSec: duration,
            isWarmup: set.isWarmup,
            completedAt: set.completedAt,
          ),
        );
      });

  /// Ends the session (SPEC §6.3): exercises without sets become skipped,
  /// open or active ones with sets become done. [endedAt] defaults to now.
  Future<void> finishSession(int sessionId, {DateTime? endedAt}) =>
      _db.transaction(() async {
        final session = await _db.sessionsDao.findById(sessionId);
        if (session == null) throw NotFoundException('session', sessionId);
        if (!session.isActive) throw SessionNotActiveException(sessionId);
        for (final se in await _db.sessionsDao.getSessionExercises(sessionId)) {
          if (!isMovable(se.status)) continue;
          final sets = await _db.sessionsDao.getSets(se.id);
          await _db.sessionsDao.updateSessionExercise(
            sets.isEmpty
                ? se.copyWith(status: SessionExerciseStatus.skipped)
                : se.copyWith(
                    status: SessionExerciseStatus.done,
                    completedAt: sets.last.completedAt,
                  ),
          );
        }
        final end = storageTime(endedAt ?? _clock.now());
        await _db.sessionsDao.updateSession(
          session.copyWith(
            endedAt: end.isBefore(session.startedAt) ? session.startedAt : end,
          ),
        );
      });

  Future<void> updateNotes(int sessionId, String notes) =>
      _db.transaction(() async {
        final session = await _db.sessionsDao.findById(sessionId);
        if (session == null) throw NotFoundException('session', sessionId);
        await _db.sessionsDao.updateSession(
          session.copyWith(notes: notes.trim()),
        );
      });

  /// Time of the latest set of the session, if any.
  Future<DateTime?> lastSetTime(int sessionId) =>
      _db.sessionsDao.lastSetTime(sessionId);

  Future<List<SessionExerciseDetail>> getDetails(int sessionId) =>
      _db.sessionsDao.getDetails(sessionId);

  /// The previous finished session of the same plan, with its details.
  Future<List<SessionExerciseDetail>?> previousPlanSessionDetails(
    Session session,
  ) async {
    final planId = session.planId;
    if (planId == null) return null;
    final previous = await _db.sessionsDao.previousPlanSession(
      planId,
      session.startedAt,
    );
    return previous == null ? null : getDetails(previous.id);
  }

  Stream<Session?> watchSession(int sessionId) =>
      _db.sessionsDao.watchById(sessionId);

  /// Finished sessions, newest first, with their key figures (SPEC §6.4).
  Stream<List<SessionSummary>> watchHistory() =>
      _db.sessionsDao.watchSetChanges().asyncMap((_) => _history());

  Future<List<SessionSummary>> _history() async {
    final sessions = await _db.sessionsDao.finishedSessions();
    final all = await _db.sessionsDao.allSetsWithContext();
    final count = <int, int>{};
    final volume = <int, double>{};
    final byExercise = <int, List<HistorySet>>{};
    final types = <int, ExerciseType>{};
    for (final x in all) {
      if (x.set.isWarmup) continue;
      count[x.sessionId] = (count[x.sessionId] ?? 0) + 1;
      if (x.type == ExerciseType.weightReps) {
        volume[x.sessionId] =
            (volume[x.sessionId] ?? 0) +
            (x.set.weightKg ?? 0) * (x.set.reps ?? 0);
      }
      byExercise.putIfAbsent(x.exerciseId, () => []).add((
        set: x.set,
        sessionId: x.sessionId,
      ));
      types[x.exerciseId] = x.type;
    }
    final withRecords = <int>{};
    for (final MapEntry(key: exerciseId, value: sets) in byExercise.entries) {
      final flagged = detectRecords(types[exerciseId]!, sets).keys.toSet();
      for (final h in sets) {
        if (flagged.contains(h.set.id)) withRecords.add(h.sessionId);
      }
    }
    return [
      for (final s in sessions)
        SessionSummary(
          session: s,
          setCount: count[s.id] ?? 0,
          volume: volume[s.id] ?? 0,
          hasRecords: withRecords.contains(s.id),
        ),
    ];
  }

  /// Changes start and end of a finished session (SPEC §6.4).
  Future<void> updateSessionTimes(
    int sessionId, {
    required DateTime start,
    required DateTime end,
  }) => _db.transaction(() async {
    final session = await _db.sessionsDao.findById(sessionId);
    if (session == null) throw NotFoundException('session', sessionId);
    if (session.isActive) throw const InvalidValueException('endedAt', null);
    final s = storageTime(start);
    final e = storageTime(end);
    final error = validateSessionTimes(start: s, end: e, now: _clock.now());
    if (error != null) throw InvalidValueException(error.name, (s, e));
    await _db.sessionsDao.updateSession(
      session.copyWith(startedAt: s, endedAt: e),
    );
  });

  /// Removes an exercise with all its sets from a session.
  Future<void> removeSessionExercise(int sessionExerciseId) =>
      _db.transaction(() async {
        final se = await _db.sessionsDao.findSessionExercise(sessionExerciseId);
        if (se == null) {
          throw NotFoundException('sessionExercise', sessionExerciseId);
        }
        await _db.sessionsDao.deleteSessionExercise(sessionExerciseId);
      });

  /// Record sets of a session by set id, updated live (label "Rekord").
  Stream<Map<int, List<RecordKind>>> watchSessionRecords(int sessionId) => _db
      .sessionsDao
      .watchSetChanges()
      .asyncMap((_) => _sessionRecordSets(sessionId));

  /// New records of a session: the best value per exercise and record kind
  /// among the sets that set a record.
  Future<List<SessionRecord>> sessionRecords(int sessionId) async {
    final details = await getDetails(sessionId);
    final flagged = await _sessionRecordSets(sessionId);
    final result = <SessionRecord>[];
    for (final d in details) {
      for (final kind in recordKindsFor(d.exercise.type)) {
        double? best;
        for (final set in d.sets) {
          if (!(flagged[set.id]?.contains(kind) ?? false)) continue;
          final value = recordValue(kind, set)!;
          if (best == null || value > best) best = value;
        }
        if (best != null) {
          result.add(
            SessionRecord(exercise: d.exercise, kind: kind, value: best),
          );
        }
      }
    }
    return result;
  }

  Future<Map<int, List<RecordKind>>> _sessionRecordSets(int sessionId) async {
    final details = await getDetails(sessionId);
    final setIds = {for (final d in details) ...d.sets.map((s) => s.id)};
    final result = <int, List<RecordKind>>{};
    for (final d in details) {
      if (d.sets.isEmpty) continue;
      for (final MapEntry(key: id, value: kinds) in (await _recordsOfExercise(
        d.exercise,
      )).entries) {
        if (setIds.contains(id)) result[id] = kinds;
      }
    }
    return result;
  }

  Future<Map<int, List<RecordKind>>> _recordsOfExercise(
    Exercise exercise,
  ) async => detectRecords(
    exercise.type,
    await _db.sessionsDao.historySets(exercise.id),
  );

  Future<List<SessionExercise>> _exercisesOfSessionOf(
    int sessionExerciseId,
  ) async {
    final se = await _db.sessionsDao.findSessionExercise(sessionExerciseId);
    if (se == null) {
      throw NotFoundException('sessionExercise', sessionExerciseId);
    }
    return _db.sessionsDao.getSessionExercises(se.sessionId);
  }

  Future<SessionExercise> _requireInActiveSession(int sessionExerciseId) async {
    final se = await _db.sessionsDao.findSessionExercise(sessionExerciseId);
    if (se == null) {
      throw NotFoundException('sessionExercise', sessionExerciseId);
    }
    final session = await _db.sessionsDao.findById(se.sessionId);
    if (session == null || !session.isActive) {
      throw SessionNotActiveException(se.sessionId);
    }
    return se;
  }

  Future<void> _activate(SessionExercise target) async {
    for (final e in await _db.sessionsDao.getSessionExercises(
      target.sessionId,
    )) {
      if (e.id != target.id && e.status == SessionExerciseStatus.active) {
        await _db.sessionsDao.updateSessionExercise(
          e.copyWith(status: SessionExerciseStatus.pending),
        );
      }
    }
    await _db.sessionsDao.updateSessionExercise(
      target.copyWith(status: SessionExerciseStatus.active, completedAt: null),
    );
  }

  Future<void> _autoActivateNext(SessionExercise completed) async {
    if (!(await _db.settingsDao.get()).autoActivateNext) return;
    final all = await _db.sessionsDao.getSessionExercises(completed.sessionId);
    if (all.any((e) => e.status == SessionExerciseStatus.active)) return;
    final next = nextPendingExercise(all, afterId: completed.id);
    if (next != null) await _activate(all.firstWhere((e) => e.id == next));
  }

  static (double?, int?, int?) _fieldsFor(ExerciseType type, SetValues v) =>
      switch (type) {
        ExerciseType.weightReps => (v.weightKg, v.reps, null),
        ExerciseType.bodyweight => (v.weightKg ?? 0.0, v.reps, null),
        ExerciseType.timed => (v.weightKg, null, v.durationSec),
      };

  /// Deletes a set and renumbers the following sets of the same exercise.
  Future<void> deleteSet(int setId) => _db.transaction(() async {
    final set = await _db.sessionsDao.findSet(setId);
    if (set == null) throw NotFoundException('set', setId);
    await _db.sessionsDao.deleteSet(setId);
    await _db.customUpdate(
      'UPDATE set_entries SET set_index = set_index - 1 '
      'WHERE session_exercise_id = ? AND set_index > ?',
      variables: [
        Variable.withInt(set.sessionExerciseId),
        Variable.withInt(set.setIndex),
      ],
      updates: {_db.setEntries},
    );
  });

  /// Ends a running session now (see [finishSession]).
  Future<void> finish(int sessionId) => finishSession(sessionId);

  /// Deletes a session with all its exercises and sets.
  Future<void> delete(int sessionId) => _db.transaction(() async {
    final session = await _db.sessionsDao.findById(sessionId);
    if (session == null) throw NotFoundException('session', sessionId);
    await _db.sessionsDao.deleteById(sessionId);
  });
}
