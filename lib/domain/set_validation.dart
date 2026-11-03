import 'models/enums.dart';

/// Why the values of a set are not valid for its exercise type (SPEC §5).
enum SetValidationError {
  /// `weight_reps` needs a weight.
  weightRequired,

  /// Weight must not be negative (`weight_reps`, `timed`).
  weightNegative,

  /// `weight_reps`/`bodyweight` need at least one repetition.
  repsRequired,

  /// `timed` needs a duration of at least one second.
  durationRequired,

  /// Value is not a finite number.
  invalidNumber,
}

/// Checks the values of a set for [type]. Returns `null` if they are valid.
///
/// Fields that do not belong to the type (e.g. a duration for `weight_reps`)
/// are ignored here; the repository stores `null` for them.
SetValidationError? validateSet(
  ExerciseType type, {
  double? weightKg,
  int? reps,
  int? durationSec,
}) {
  if (weightKg != null && !weightKg.isFinite) {
    return SetValidationError.invalidNumber;
  }
  switch (type) {
    case ExerciseType.weightReps:
      if (weightKg == null) return SetValidationError.weightRequired;
      if (weightKg < 0) return SetValidationError.weightNegative;
      if (reps == null || reps < 1) return SetValidationError.repsRequired;
    case ExerciseType.bodyweight:
      if (reps == null || reps < 1) return SetValidationError.repsRequired;
    case ExerciseType.timed:
      if (durationSec == null || durationSec < 1) {
        return SetValidationError.durationRequired;
      }
      if (weightKg != null && weightKg < 0) {
        return SetValidationError.weightNegative;
      }
  }
  return null;
}
