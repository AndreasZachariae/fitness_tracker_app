import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../domain/models/models.dart';
import '../../domain/set_validation.dart';
import '../db/database.dart';
import '../db/storage_time.dart';
import 'repository_exceptions.dart';

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

    final (weight, storedReps, duration) = switch (exercise.type) {
      ExerciseType.weightReps => (weightKg, reps, null),
      ExerciseType.bodyweight => (weightKg ?? 0.0, reps, null),
      ExerciseType.timed => (weightKg, null, durationSec),
    };

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

  /// Ends a running session now.
  Future<void> finish(int sessionId) => _db.transaction(() async {
    final session = await _db.sessionsDao.findById(sessionId);
    if (session == null) throw NotFoundException('session', sessionId);
    if (!session.isActive) throw SessionNotActiveException(sessionId);
    await _db.sessionsDao.updateSession(
      session.copyWith(endedAt: storageTime(_clock.now())),
    );
  });

  /// Deletes a session with all its exercises and sets.
  Future<void> delete(int sessionId) => _db.transaction(() async {
    final session = await _db.sessionsDao.findById(sessionId);
    if (session == null) throw NotFoundException('session', sessionId);
    await _db.sessionsDao.deleteById(sessionId);
  });
}
