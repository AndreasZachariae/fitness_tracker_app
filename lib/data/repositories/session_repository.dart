import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../domain/groups.dart';
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
    // Supersets need at least two exercises.
    final keyCount = <int, int>{};
    for (final d in exercises) {
      if (d.supersetKey case final k?) keyCount[k] = (keyCount[k] ?? 0) + 1;
    }
    final supersetIds = <int, int>{};
    for (final d in exercises) {
      final k = d.supersetKey;
      if (k == null || keyCount[k]! < 2 || supersetIds.containsKey(k)) {
        continue;
      }
      supersetIds[k] = await _db.sessionsDao.insertSuperset(
        SessionSupersetsCompanion.insert(
          sessionId: sessionId,
          restSec: Value(d.supersetRestSec),
        ),
      );
    }
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
          supersetId: Value(supersetIds[draft.supersetKey]),
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
        }
        final members = await _supersetMembers(se);
        if (members != null) {
          // Superset (M9): always on to the next member; when the whole
          // superset is done, as for a single exercise.
          final step = afterSupersetSet(members, se.id, set.setIndex);
          if (step.nextId case final next?) {
            await _activate((await _db.sessionsDao.findSessionExercise(next))!);
          } else {
            await _autoActivateNext(se);
          }
        } else if (completed) {
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
    await _continueAfter(se);
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
        await _continueAfter(se);
      });

  /// "+1 Satz": one more target set.
  Future<void> addTargetSet(int sessionExerciseId) => _db.transaction(() async {
    final se = await _requireInActiveSession(sessionExerciseId);
    await _db.sessionsDao.updateSessionExercise(
      se.copyWith(targetSets: se.targetSets + 1),
    );
  });

  /// Adds an exercise to the running session only (not to the plan); with
  /// [supersetId] at the end of that superset.
  Future<int> addExerciseToSession(
    int sessionId,
    int exerciseId,
    ExerciseTargets targets, {
    int? supersetId,
  }) => _db.transaction(() async {
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
    if (supersetId != null) {
      final superset = await _db.sessionsDao.findSuperset(supersetId);
      if (superset == null || superset.sessionId != sessionId) {
        throw NotFoundException('sessionSuperset', supersetId);
      }
    }
    final id = await _db.sessionsDao.insertSessionExercise(
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
    if (supersetId != null) {
      final all = await _db.sessionsDao.getSessionExercises(sessionId);
      final added = all.firstWhere((e) => e.id == id);
      final others = [
        for (final e in all)
          if (e.id != id) e,
      ];
      final last = others.lastIndexWhere((e) => e.supersetId == supersetId);
      await _writeSessionOrder(
        [...others]..insert(last + 1, added.copyWith(supersetId: supersetId)),
        all,
      );
    }
    return id;
  });

  /// New order of a session's exercises. Done and skipped exercises must
  /// keep their places (SPEC §6.2).
  Future<void> reorderSession(int sessionId, List<int> sessionExerciseIds) =>
      _db.transaction(() async {
        final current = await _db.sessionsDao.getSessionExercises(sessionId);
        final byId = {for (final e in current) e.id: e};
        final isPermutation =
            sessionExerciseIds.length == current.length &&
            sessionExerciseIds.toSet().containsAll(byId.keys);
        // Done and skipped exercises (and supersets containing one) keep
        // their places; supersets stay together (M9).
        final valid =
            isPermutation &&
            _keepsFixedPlaces(
              blocksOf(current, (e) => e.supersetId),
              blocksOf([
                for (final id in sessionExerciseIds) byId[id]!,
              ], (e) => e.supersetId),
            );
        if (!valid) {
          throw InvalidValueException('sessionExerciseIds', sessionExerciseIds);
        }
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
        if (session.planId case final planId?) {
          await _advanceRotations(planId, sessionId);
        }
      });

  /// Rotations of the plan move on when their due exercise was trained in
  /// the session (M9).
  Future<void> _advanceRotations(int planId, int sessionId) async {
    final groups = await _db.plansDao.getGroups(planId);
    if (!groups.any((g) => g.kind == PlanGroupKind.rotation)) return;
    final entries = await _db.plansDao.getEntries(planId);
    final trained = <int>{
      for (final d in await _db.sessionsDao.getDetails(sessionId))
        if (d.sets.any((s) => !s.isWarmup)) d.exercise.id,
    };
    for (final g in groups) {
      if (g.kind != PlanGroupKind.rotation) continue;
      final members = [
        for (final e in entries)
          if (e.planExercise.groupId == g.id) e.exercise.id,
      ];
      final current = members.isEmpty
          ? null
          : members[rotationIndex(members, g.rotationExerciseId)];
      final next = advanceRotation(
        memberExerciseIds: members,
        currentExerciseId: g.rotationExerciseId,
        done: g.rotationDone,
        every: g.rotationEvery,
        trained: current != null && trained.contains(current),
      );
      if (next.exerciseId != g.rotationExerciseId ||
          next.done != g.rotationDone) {
        await _db.plansDao.updateGroup(
          g.copyWith(
            rotationExerciseId: next.exerciseId,
            rotationDone: next.done,
          ),
        );
      }
    }
  }

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
        if (se.supersetId case final supersetId?) {
          await _dissolveIfTooSmall(se.sessionId, supersetId);
        }
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

  /// After skipping or finishing [se]: in a superset the next member with
  /// sets left becomes active; otherwise as configured.
  Future<void> _continueAfter(SessionExercise se) async {
    final members = await _supersetMembers(se);
    final next = members == null ? null : nextSupersetMember(members, se.id);
    if (next != null) {
      await _activate((await _db.sessionsDao.findSessionExercise(next))!);
    } else {
      await _autoActivateNext(se);
    }
  }

  /// Members of the superset of [se] in order, `null` if it has none.
  Future<List<SupersetMember>?> _supersetMembers(SessionExercise se) async {
    final supersetId = se.supersetId;
    if (supersetId == null) return null;
    final members = [
      for (final d in await _db.sessionsDao.getDetails(se.sessionId))
        if (d.sessionExercise.supersetId == supersetId) supersetMemberOf(d),
    ];
    return members.length < 2 ? null : members;
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

  // ---------------------------------------------------------------------------
  // Supersets (M9)

  Stream<Map<int, SessionSuperset>> watchSupersets(int sessionId) => _db
      .sessionsDao
      .watchSupersets(sessionId)
      .map((list) => {for (final x in list) x.id: x});

  Future<Map<int, SessionSuperset>> getSupersets(int sessionId) async => {
    for (final x in await _db.sessionsDao.getSupersets(sessionId)) x.id: x,
  };

  /// Forms a superset of open exercises of the running session (at least
  /// two, none in a superset yet). They keep their relative order and move
  /// together to the place of the first one. Returns the superset id.
  Future<int> createSuperset(
    int sessionId,
    List<int> sessionExerciseIds, {
    int? restSec,
  }) => _db.transaction(() async {
    final session = await _db.sessionsDao.findById(sessionId);
    if (session == null) throw NotFoundException('session', sessionId);
    if (!session.isActive) throw SessionNotActiveException(sessionId);
    final all = await _db.sessionsDao.getSessionExercises(sessionId);
    final chosen = sessionExerciseIds.toSet();
    final members = [
      for (final e in all)
        if (chosen.contains(e.id)) e,
    ];
    if (chosen.length < 2 ||
        members.length != chosen.length ||
        members.any((e) => e.supersetId != null || !isMovable(e.status))) {
      throw InvalidValueException('sessionExerciseIds', sessionExerciseIds);
    }
    if (restSec != null && (restSec < 0 || restSec > 3600)) {
      throw InvalidValueException('restSec', restSec);
    }
    final supersetId = await _db.sessionsDao.insertSuperset(
      SessionSupersetsCompanion.insert(
        sessionId: sessionId,
        restSec: Value(restSec),
      ),
    );
    final firstIndex = all.indexOf(members.first);
    final ordered = [
      for (final e in all)
        if (!chosen.contains(e.id) && all.indexOf(e) < firstIndex) e,
      for (final e in members) e.copyWith(supersetId: supersetId),
      for (final e in all)
        if (!chosen.contains(e.id) && all.indexOf(e) > firstIndex) e,
    ];
    await _writeSessionOrder(ordered, all);
    return supersetId;
  });

  /// Dissolves a superset; its exercises stay where they are.
  Future<void> dissolveSuperset(int supersetId) => _db.transaction(() async {
    final superset = await _db.sessionsDao.findSuperset(supersetId);
    if (superset == null) {
      throw NotFoundException('sessionSuperset', supersetId);
    }
    for (final e in await _db.sessionsDao.getSessionExercises(
      superset.sessionId,
    )) {
      if (e.supersetId == supersetId) {
        await _db.sessionsDao.updateSessionExercise(
          e.copyWith(supersetId: null),
        );
      }
    }
    await _db.sessionsDao.deleteSuperset(supersetId);
  });

  Future<void> updateSupersetRest(int supersetId, int? restSec) =>
      _db.transaction(() async {
        final superset = await _db.sessionsDao.findSuperset(supersetId);
        if (superset == null) {
          throw NotFoundException('sessionSuperset', supersetId);
        }
        if (restSec != null && (restSec < 0 || restSec > 3600)) {
          throw InvalidValueException('restSec', restSec);
        }
        await _db.sessionsDao.updateSuperset(
          superset.copyWith(restSec: restSec),
        );
      });

  /// Takes an exercise out of its superset and puts it right after it. A
  /// superset left with one exercise is dissolved.
  Future<void> removeFromSuperset(int sessionExerciseId) =>
      _db.transaction(() async {
        final se = await _db.sessionsDao.findSessionExercise(sessionExerciseId);
        if (se == null) {
          throw NotFoundException('sessionExercise', sessionExerciseId);
        }
        final supersetId = se.supersetId;
        if (supersetId == null) return;
        final all = await _db.sessionsDao.getSessionExercises(se.sessionId);
        final others = [
          for (final e in all)
            if (e.id != se.id) e,
        ];
        final last = others.lastIndexWhere((e) => e.supersetId == supersetId);
        await _writeSessionOrder(
          [...others]..insert(last + 1, se.copyWith(supersetId: null)),
          all,
        );
        await _dissolveIfTooSmall(se.sessionId, supersetId);
      });

  Future<void> _dissolveIfTooSmall(int sessionId, int supersetId) async {
    final members = (await _db.sessionsDao.getSessionExercises(sessionId))
        .where((e) => e.supersetId == supersetId)
        .length;
    if (members < 2) await dissolveSuperset(supersetId);
  }

  /// Writes positions and superset ids of [ordered] where they changed.
  Future<void> _writeSessionOrder(
    List<SessionExercise> ordered,
    List<SessionExercise> before,
  ) async {
    final old = {for (final e in before) e.id: e};
    for (final (i, e) in ordered.indexed) {
      final o = old[e.id]!;
      if (o.position != i || o.supersetId != e.supersetId) {
        await _db.sessionsDao.updateSessionExercise(
          o.copyWith(position: i, supersetId: e.supersetId),
        );
      }
    }
  }

  /// Fixed blocks (with a done or skipped exercise) keep their block
  /// index, and inside a block done/skipped exercises keep their index.
  static bool _keepsFixedPlaces(
    List<Block<SessionExercise>> before,
    List<Block<SessionExercise>> after,
  ) {
    if (before.length != after.length) return false;
    for (var i = 0; i < before.length; i++) {
      final b = before[i];
      if (b.items.every((e) => isMovable(e.status))) continue;
      final a = after[i];
      if (a.groupId != b.groupId || a.items.length != b.items.length) {
        return false;
      }
      for (var k = 0; k < b.items.length; k++) {
        if (!isMovable(b.items[k].status) && a.items[k].id != b.items[k].id) {
          return false;
        }
      }
    }
    return true;
  }

  /// Ends a running session now (see [finishSession]).
  Future<void> finish(int sessionId) => finishSession(sessionId);

  /// Deletes a session with all its exercises and sets.
  Future<DeletedSession> delete(int sessionId) => _db.transaction(() async {
    final session = await _db.sessionsDao.findById(sessionId);
    if (session == null) throw NotFoundException('session', sessionId);
    final exercises = await _db.sessionsDao.getSessionExercises(sessionId);
    final deleted = DeletedSession(
      session: session,
      supersets: await _db.sessionsDao.getSupersets(sessionId),
      exercises: exercises,
      sets: [
        for (final se in exercises) ...await _db.sessionsDao.getSets(se.id),
      ],
    );
    await _db.sessionsDao.deleteById(sessionId);
    return deleted;
  });

  /// Undoes [delete] with the same ids (1.0.1: "Rückgängig" in the
  /// history). A plan deleted in the meantime is dropped from the session;
  /// the plan name stays.
  Future<void> restoreDeleted(DeletedSession deleted) =>
      _db.transaction(() async {
        var session = deleted.session;
        if (session.isActive) {
          if (await _db.sessionsDao.getActive() case final active?) {
            throw ActiveSessionExistsException(active.id);
          }
        }
        if (session.planId case final planId?
            when await _db.plansDao.findById(planId) == null) {
          session = session.copyWith(planId: null);
        }
        await _db.batch((b) {
          b.insert(_db.sessions, session.toInsertable());
          b.insertAll(_db.sessionSupersets, [
            for (final s in deleted.supersets) s.toInsertable(),
          ]);
          b.insertAll(_db.sessionExercises, [
            for (final e in deleted.exercises) e.toInsertable(),
          ]);
          b.insertAll(_db.setEntries, [
            for (final s in deleted.sets) s.toInsertable(),
          ]);
        });
      });
}

/// A deleted session with everything that belonged to it.
final class DeletedSession {
  const DeletedSession({
    required this.session,
    required this.supersets,
    required this.exercises,
    required this.sets,
  });

  final Session session;
  final List<SessionSuperset> supersets;
  final List<SessionExercise> exercises;
  final List<SetEntry> sets;
}
