import 'copy.dart';
import 'enums.dart';
import 'exercise.dart';

/// A training session (table `sessions`).
final class Session {
  const Session({
    required this.id,
    required this.planId,
    required this.planNameSnapshot,
    required this.startedAt,
    required this.endedAt,
    required this.notes,
  });

  final int id;

  /// `null` for free training or when the plan was deleted.
  final int? planId;

  /// Plan name at training time; `null` = free training.
  final String? planNameSnapshot;

  /// UTC.
  final DateTime startedAt;

  /// UTC; `null` = the session is still running.
  final DateTime? endedAt;
  final String notes;

  bool get isActive => endedAt == null;

  bool get isFreeTraining => planNameSnapshot == null;

  Session copyWith({
    Object? planId = unset,
    DateTime? startedAt,
    Object? endedAt = unset,
    String? notes,
  }) {
    return Session(
      id: id,
      planId: pick<int?>(planId, this.planId),
      planNameSnapshot: planNameSnapshot,
      startedAt: startedAt ?? this.startedAt,
      endedAt: pick<DateTime?>(endedAt, this.endedAt),
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.id == id &&
      other.planId == planId &&
      other.planNameSnapshot == planNameSnapshot &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.notes == notes;

  @override
  int get hashCode =>
      Object.hash(id, planId, planNameSnapshot, startedAt, endedAt, notes);

  @override
  String toString() => 'Session($id, ${planNameSnapshot ?? 'free'})';
}

/// An exercise within a session (table `session_exercises`).
final class SessionExercise {
  const SessionExercise({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.position,
    required this.targetSets,
    required this.targetReps,
    required this.targetDurationSec,
    required this.restSec,
    required this.status,
    required this.completedAt,
  });

  final int id;
  final int sessionId;
  final int exerciseId;
  final int position;
  final int targetSets;
  final int? targetReps;
  final int? targetDurationSec;
  final int? restSec;
  final SessionExerciseStatus status;

  /// UTC.
  final DateTime? completedAt;

  SessionExercise copyWith({
    int? position,
    int? targetSets,
    SessionExerciseStatus? status,
    Object? completedAt = unset,
  }) {
    return SessionExercise(
      id: id,
      sessionId: sessionId,
      exerciseId: exerciseId,
      position: position ?? this.position,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps,
      targetDurationSec: targetDurationSec,
      restSec: restSec,
      status: status ?? this.status,
      completedAt: pick<DateTime?>(completedAt, this.completedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SessionExercise &&
      other.id == id &&
      other.sessionId == sessionId &&
      other.exerciseId == exerciseId &&
      other.position == position &&
      other.targetSets == targetSets &&
      other.targetReps == targetReps &&
      other.targetDurationSec == targetDurationSec &&
      other.restSec == restSec &&
      other.status == status &&
      other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    exerciseId,
    position,
    targetSets,
    targetReps,
    targetDurationSec,
    restSec,
    status,
    completedAt,
  );

  @override
  String toString() =>
      'SessionExercise($id, session $sessionId, exercise $exerciseId, '
      '${status.code})';
}

/// One recorded set (table `set_entries`).
final class SetEntry {
  const SetEntry({
    required this.id,
    required this.sessionExerciseId,
    required this.setIndex,
    required this.weightKg,
    required this.reps,
    required this.durationSec,
    required this.isWarmup,
    required this.completedAt,
  });

  final int id;
  final int sessionExerciseId;

  /// Starts at 1.
  final int setIndex;

  /// `weight_reps`: weight (required); `bodyweight`: added weight
  /// (negative = assistance); `timed`: optional added weight.
  final double? weightKg;
  final int? reps;
  final int? durationSec;

  /// Reserved for later; v1 has no UI for warm-up sets.
  final bool isWarmup;

  /// UTC.
  final DateTime completedAt;

  @override
  bool operator ==(Object other) =>
      other is SetEntry &&
      other.id == id &&
      other.sessionExerciseId == sessionExerciseId &&
      other.setIndex == setIndex &&
      other.weightKg == weightKg &&
      other.reps == reps &&
      other.durationSec == durationSec &&
      other.isWarmup == isWarmup &&
      other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(
    id,
    sessionExerciseId,
    setIndex,
    weightKg,
    reps,
    durationSec,
    isWarmup,
    completedAt,
  );

  @override
  String toString() =>
      'SetEntry($id, #$setIndex, $weightKg kg × $reps, ${durationSec}s)';
}

/// Targets of an exercise when a session is started.
final class SessionExerciseDraft {
  const SessionExerciseDraft({
    required this.exerciseId,
    required this.targetSets,
    this.targetReps,
    this.targetDurationSec,
    this.restSec,
  });

  final int exerciseId;
  final int targetSets;
  final int? targetReps;
  final int? targetDurationSec;
  final int? restSec;
}

/// The working sets of an exercise in the last finished session that
/// contains it (reference "Zuletzt: …", SPEC §6.1).
final class LastPerformance {
  const LastPerformance({
    required this.exerciseId,
    required this.sessionStartedAt,
    required this.sets,
  });

  final int exerciseId;

  /// UTC.
  final DateTime sessionStartedAt;

  /// Ordered by set index; never empty.
  final List<SetEntry> sets;
}

/// A session exercise with its exercise and its sets (ordered by index).
final class SessionExerciseDetail {
  const SessionExerciseDetail({
    required this.sessionExercise,
    required this.exercise,
    required this.sets,
  });

  final SessionExercise sessionExercise;
  final Exercise exercise;
  final List<SetEntry> sets;
}
