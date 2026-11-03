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
  });

  final int id;
  final String name;
  final ExerciseType type;
  final ExerciseCategory? category;

  /// Step of the weight stepper.
  final double incrementKg;

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
      other.createdAt == createdAt;

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
}
