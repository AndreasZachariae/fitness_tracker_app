import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/metrics.dart';
import 'package:gymlog/domain/models/models.dart';

SetEntry s(int i, {double? w, int? r, int? d, bool warmup = false}) => SetEntry(
  id: i,
  sessionExerciseId: 1,
  setIndex: i,
  weightKg: w,
  reps: r,
  durationSec: d,
  isWarmup: warmup,
  completedAt: DateTime.utc(2026),
);

SessionExerciseDetail detail(ExerciseType type, List<SetEntry> sets) =>
    SessionExerciseDetail(
      sessionExercise: const SessionExercise(
        id: 1,
        sessionId: 1,
        exerciseId: 1,
        position: 0,
        targetSets: 3,
        targetReps: null,
        targetDurationSec: null,
        restSec: null,
        status: SessionExerciseStatus.done,
        completedAt: null,
      ),
      exercise: Exercise(
        id: 1,
        name: 'x',
        type: type,
        category: null,
        incrementKg: 2.5,
        restSec: null,
        includeInStrengthIndex: true,
        notes: '',
        archived: false,
        createdAt: DateTime.utc(2026),
      ),
      sets: sets,
    );

void main() {
  test('volume counts weight_reps working sets only (SPEC §7.6)', () {
    final v = sessionVolume([
      detail(ExerciseType.weightReps, [
        s(1, w: 60, r: 10),
        s(2, w: 62.5, r: 8),
        s(3, w: 20, r: 10, warmup: true),
      ]),
      detail(ExerciseType.bodyweight, [s(1, w: 10, r: 10)]),
      detail(ExerciseType.timed, [s(1, w: 10, d: 60)]),
    ]);
    expect(v, 600 + 500);
    expect(sessionVolume(const []), 0);
  });

  test('percentChange', () {
    expect(percentChange(110, 100), closeTo(10, 1e-9));
    expect(percentChange(90, 100), closeTo(-10, 1e-9));
    expect(percentChange(100, null), isNull);
    expect(percentChange(100, 0), isNull);
  });

  final best = <(ExerciseType, List<SetEntry>, int)>[
    (
      ExerciseType.weightReps,
      [s(1, w: 60, r: 10), s(2, w: 62.5, r: 8), s(3, w: 62.5, r: 9)],
      3,
    ),
    (
      ExerciseType.bodyweight,
      [s(1, w: 0, r: 10), s(2, w: 5, r: 10), s(3, w: 0, r: 8)],
      2,
    ),
    (ExerciseType.timed, [s(1, d: 45), s(2, d: 60), s(3, d: 50)], 2),
    (
      ExerciseType.weightReps,
      [s(1, w: 60, r: 10), s(2, w: 100, r: 1, warmup: true)],
      1,
    ),
  ];
  for (final (type, sets, expected) in best) {
    test('bestSet ${type.code} → set $expected', () {
      expect(bestSet(type, sets)!.setIndex, expected);
    });
  }
  test('bestSet of nothing', () {
    expect(bestSet(ExerciseType.timed, const []), isNull);
  });
}
