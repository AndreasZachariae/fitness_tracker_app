import 'copy.dart';
import 'exercise.dart';

/// A training plan (table `plans`).
final class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.position,
    required this.createdAt,
    this.active = true,
  });

  final int id;
  final String name;

  /// Order of the plan chips.
  final int position;

  /// UTC.
  final DateTime createdAt;

  /// Currently trained (1.2.0): only active plans remind; inactive ones are
  /// shown greyed out.
  final bool active;

  Plan copyWith({String? name, int? position, bool? active}) => Plan(
    id: id,
    name: name ?? this.name,
    position: position ?? this.position,
    createdAt: createdAt,
    active: active ?? this.active,
  );

  @override
  bool operator ==(Object other) =>
      other is Plan &&
      other.id == id &&
      other.name == name &&
      other.position == position &&
      other.createdAt == createdAt &&
      other.active == active;

  @override
  int get hashCode => Object.hash(id, name, position, createdAt, active);

  @override
  String toString() => 'Plan($id, $name)';
}

/// A training day of a plan (table `plan_schedules`, 1.2.0): weekday
/// 1 = Monday … 7 = Sunday, local time as minutes after midnight.
final class PlanScheduleEntry {
  const PlanScheduleEntry({
    required this.id,
    required this.planId,
    required this.weekday,
    required this.minuteOfDay,
  });

  final int id;
  final int planId;
  final int weekday;
  final int minuteOfDay;

  @override
  bool operator ==(Object other) =>
      other is PlanScheduleEntry &&
      other.id == id &&
      other.planId == planId &&
      other.weekday == weekday &&
      other.minuteOfDay == minuteOfDay;

  @override
  int get hashCode => Object.hash(id, planId, weekday, minuteOfDay);

  @override
  String toString() => 'PlanScheduleEntry($planId, $weekday, $minuteOfDay)';
}

/// An exercise in a plan with its targets (table `plan_exercises`).
final class PlanExercise {
  const PlanExercise({
    required this.id,
    required this.planId,
    required this.exerciseId,
    required this.position,
    required this.targetSets,
    required this.targetReps,
    required this.targetDurationSec,
    required this.restSec,
    this.groupId,
  });

  final int id;
  final int planId;
  final int exerciseId;

  /// Superset or rotation this entry belongs to (M9); `null` = single.
  final int? groupId;
  final int position;

  /// 1–10.
  final int targetSets;
  final int? targetReps;
  final int? targetDurationSec;

  /// Overrides the rest time of the exercise; `null` = not set.
  final int? restSec;

  PlanExercise copyWith({
    int? position,
    int? targetSets,
    Object? targetReps = unset,
    Object? targetDurationSec = unset,
    Object? restSec = unset,
    Object? groupId = unset,
  }) {
    return PlanExercise(
      id: id,
      planId: planId,
      exerciseId: exerciseId,
      position: position ?? this.position,
      targetSets: targetSets ?? this.targetSets,
      targetReps: pick<int?>(targetReps, this.targetReps),
      targetDurationSec: pick<int?>(targetDurationSec, this.targetDurationSec),
      restSec: pick<int?>(restSec, this.restSec),
      groupId: pick<int?>(groupId, this.groupId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlanExercise &&
      other.id == id &&
      other.planId == planId &&
      other.exerciseId == exerciseId &&
      other.position == position &&
      other.targetSets == targetSets &&
      other.targetReps == targetReps &&
      other.targetDurationSec == targetDurationSec &&
      other.restSec == restSec &&
      other.groupId == groupId;

  @override
  int get hashCode => Object.hash(
    id,
    planId,
    exerciseId,
    position,
    targetSets,
    targetReps,
    targetDurationSec,
    restSec,
    groupId,
  );

  @override
  String toString() => 'PlanExercise($id, plan $planId, exercise $exerciseId)';
}

/// A plan exercise together with its exercise.
final class PlanEntry {
  const PlanEntry({required this.planExercise, required this.exercise});

  final PlanExercise planExercise;
  final Exercise exercise;

  @override
  bool operator ==(Object other) =>
      other is PlanEntry &&
      other.planExercise == planExercise &&
      other.exercise == exercise;

  @override
  int get hashCode => Object.hash(planExercise, exercise);
}
