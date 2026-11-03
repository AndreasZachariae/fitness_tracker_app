import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/enums.dart';
import 'package:gymlog/domain/set_validation.dart';

void main() {
  const w = ExerciseType.weightReps;
  const b = ExerciseType.bodyweight;
  const t = ExerciseType.timed;
  final cases = <(ExerciseType, double?, int?, int?, SetValidationError?)>[
    (w, 62.5, 10, null, null),
    (w, 0, 1, null, null),
    (w, null, 10, null, SetValidationError.weightRequired),
    (w, -2.5, 10, null, SetValidationError.weightNegative),
    (w, 60, 0, null, SetValidationError.repsRequired),
    (w, 60, null, null, SetValidationError.repsRequired),
    (w, double.nan, 10, null, SetValidationError.invalidNumber),
    (w, double.infinity, 10, null, SetValidationError.invalidNumber),
    (b, null, 8, null, null),
    (b, 0, 8, null, null),
    (b, 10, 8, null, null),
    (b, -20, 8, null, null), // assistance
    (b, 0, 0, null, SetValidationError.repsRequired),
    (t, null, null, 45, null),
    (t, 10, null, 45, null),
    (t, null, null, 0, SetValidationError.durationRequired),
    (t, null, null, null, SetValidationError.durationRequired),
    (t, -5, null, 45, SetValidationError.weightNegative),
  ];
  for (final (type, weight, reps, duration, expected) in cases) {
    test('${type.code} weight=$weight reps=$reps duration=$duration '
        '→ ${expected?.name ?? 'ok'}', () {
      expect(
        validateSet(type, weightKg: weight, reps: reps, durationSec: duration),
        expected,
      );
    });
  }
}
