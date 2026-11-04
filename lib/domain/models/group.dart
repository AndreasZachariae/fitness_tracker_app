import 'copy.dart';
import 'enums.dart';

/// Allowed range of "change after N trainings" of a rotation.
const minRotationEvery = 1;
const maxRotationEvery = 10;

/// A superset or rotation inside a plan (table `plan_groups`, M9).
///
/// Members are the plan exercises with this `groupId`; they are contiguous
/// in the plan order.
final class PlanGroup {
  const PlanGroup({
    required this.id,
    required this.planId,
    required this.kind,
    required this.restSec,
    required this.rotationEvery,
    required this.rotationExerciseId,
    required this.rotationDone,
  });

  final int id;
  final int planId;
  final PlanGroupKind kind;

  /// Superset: rest after each round; `null` = rest of the last exercise.
  final int? restSec;

  /// Rotation: number of trainings per exercise before the next one is due.
  final int rotationEvery;

  /// Rotation: the exercise due in the next training; `null` (or an
  /// exercise no longer in the rotation) = the first member.
  final int? rotationExerciseId;

  /// Rotation: trainings already done with [rotationExerciseId].
  final int rotationDone;

  PlanGroup copyWith({
    Object? restSec = unset,
    int? rotationEvery,
    Object? rotationExerciseId = unset,
    int? rotationDone,
  }) => PlanGroup(
    id: id,
    planId: planId,
    kind: kind,
    restSec: pick<int?>(restSec, this.restSec),
    rotationEvery: rotationEvery ?? this.rotationEvery,
    rotationExerciseId: pick<int?>(rotationExerciseId, this.rotationExerciseId),
    rotationDone: rotationDone ?? this.rotationDone,
  );

  @override
  bool operator ==(Object other) =>
      other is PlanGroup &&
      other.id == id &&
      other.planId == planId &&
      other.kind == kind &&
      other.restSec == restSec &&
      other.rotationEvery == rotationEvery &&
      other.rotationExerciseId == rotationExerciseId &&
      other.rotationDone == rotationDone;

  @override
  int get hashCode => Object.hash(
    id,
    planId,
    kind,
    restSec,
    rotationEvery,
    rotationExerciseId,
    rotationDone,
  );

  @override
  String toString() => 'PlanGroup($id, ${kind.code}, plan $planId)';
}

/// A superset inside a session (table `session_supersets`, M9).
final class SessionSuperset {
  const SessionSuperset({
    required this.id,
    required this.sessionId,
    required this.restSec,
  });

  final int id;
  final int sessionId;

  /// Rest after each round; `null` = rest of the last exercise.
  final int? restSec;

  SessionSuperset copyWith({Object? restSec = unset}) => SessionSuperset(
    id: id,
    sessionId: sessionId,
    restSec: pick<int?>(restSec, this.restSec),
  );

  @override
  bool operator ==(Object other) =>
      other is SessionSuperset &&
      other.id == id &&
      other.sessionId == sessionId &&
      other.restSec == restSec;

  @override
  int get hashCode => Object.hash(id, sessionId, restSec);

  @override
  String toString() => 'SessionSuperset($id, session $sessionId)';
}
