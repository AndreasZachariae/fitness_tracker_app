import 'copy.dart';
import 'enums.dart';

/// An exercise of the library (table `exercises`).
final class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.incrementKg,
    required this.restSec,
    required this.includeInStrengthIndex,
    required this.notes,
    required this.archived,
    required this.createdAt,
    this.stepMode = StepMode.kg,
    this.incrementLbs = defaultIncrementLbs,
    this.levelKg,
    this.timerCountdown = false,
  });

  static const defaultIncrementLbs = 15.0;

  final int id;
  final String name;
  final ExerciseType type;
  final ExerciseCategory? category;

  /// Own step of the weight stepper in kg ([StepMode.kg]).
  final double incrementKg;

  /// How the weight goes up and down (1.1.0).
  final StepMode stepMode;

  /// Own step in lbs ([StepMode.lbs]).
  final double incrementLbs;

  /// Kg per level ([StepMode.levels]); `null` = unknown, then sets store
  /// the level number instead of kg.
  final double? levelKg;

  /// Timed exercises: the set timer counts down from the duration instead of
  /// up (1.3.0); switched with the arrow next to the timer.
  final bool timerCountdown;

  /// Overrides the default rest time; `null` = use the default.
  final int? restSec;
  final bool includeInStrengthIndex;

  /// Free text, e.g. "Sitzhöhe 4, Griff eng".
  final String notes;
  final bool archived;

  /// UTC.
  final DateTime createdAt;

  Exercise copyWith({
    String? name,
    ExerciseType? type,
    Object? category = unset,
    double? incrementKg,
    Object? restSec = unset,
    bool? includeInStrengthIndex,
    String? notes,
    bool? archived,
    StepMode? stepMode,
    double? incrementLbs,
    Object? levelKg = unset,
    bool? timerCountdown,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      category: pick<ExerciseCategory?>(category, this.category),
      incrementKg: incrementKg ?? this.incrementKg,
      restSec: pick<int?>(restSec, this.restSec),
      includeInStrengthIndex:
          includeInStrengthIndex ?? this.includeInStrengthIndex,
      notes: notes ?? this.notes,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      stepMode: stepMode ?? this.stepMode,
      incrementLbs: incrementLbs ?? this.incrementLbs,
      levelKg: pick<double?>(levelKg, this.levelKg),
      timerCountdown: timerCountdown ?? this.timerCountdown,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Exercise &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.category == category &&
      other.incrementKg == incrementKg &&
      other.restSec == restSec &&
      other.includeInStrengthIndex == includeInStrengthIndex &&
      other.notes == notes &&
      other.archived == archived &&
      other.createdAt == createdAt &&
      other.stepMode == stepMode &&
      other.incrementLbs == incrementLbs &&
      other.levelKg == levelKg &&
      other.timerCountdown == timerCountdown;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    category,
    incrementKg,
    restSec,
    includeInStrengthIndex,
    notes,
    archived,
    createdAt,
    stepMode,
    incrementLbs,
    levelKg,
    timerCountdown,
  );

  @override
  String toString() => 'Exercise($id, $name, ${type.code})';
}

/// Values for a new exercise.
final class ExerciseDraft {
  const ExerciseDraft({
    required this.name,
    required this.type,
    this.category,
    this.incrementKg = defaultIncrementKg,
    this.restSec,
    bool? includeInStrengthIndex,
    this.notes = '',
    this.stepMode = StepMode.kg,
    this.incrementLbs = Exercise.defaultIncrementLbs,
    this.levelKg,
  }) : includeInStrengthIndex =
           includeInStrengthIndex ??
           // Same as ExerciseType.includeInStrengthIndexByDefault (const).
           type != ExerciseType.timed;

  static const defaultIncrementKg = 2.5;

  final String name;
  final ExerciseType type;
  final ExerciseCategory? category;
  final double incrementKg;
  final int? restSec;
  final bool includeInStrengthIndex;
  final String notes;
  final StepMode stepMode;
  final double incrementLbs;
  final double? levelKg;
}
