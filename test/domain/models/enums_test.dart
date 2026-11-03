import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/enums.dart';

void main() {
  test('codes match SPEC §5 exactly', () {
    expect(ExerciseType.values.map((e) => e.code), [
      'weight_reps',
      'bodyweight',
      'timed',
    ]);
    expect(ExerciseCategory.values.map((e) => e.code), [
      'chest',
      'back',
      'legs',
      'shoulders',
      'arms',
      'core',
      'full_body',
      'other',
    ]);
    expect(SessionExerciseStatus.values.map((e) => e.code), [
      'pending',
      'active',
      'done',
      'skipped',
    ]);
    expect(ThemePreference.values.map((e) => e.code), [
      'system',
      'light',
      'dark',
    ]);
  });

  test('fromCode round-trips and rejects unknown codes', () {
    for (final t in ExerciseType.values) {
      expect(ExerciseType.fromCode(t.code), t);
    }
    expect(ExerciseCategory.fromCode('full_body'), ExerciseCategory.fullBody);
    expect(() => ExerciseType.fromCode('weightReps'), throwsFormatException);
    expect(() => SessionExerciseStatus.fromCode(''), throwsFormatException);
  });

  test('strength index default: all but timed', () {
    expect(ExerciseType.weightReps.includeInStrengthIndexByDefault, isTrue);
    expect(ExerciseType.bodyweight.includeInStrengthIndexByDefault, isTrue);
    expect(ExerciseType.timed.includeInStrengthIndexByDefault, isFalse);
  });
}
