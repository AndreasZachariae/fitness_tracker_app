import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/prefill.dart';

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

void main() {
  const w = ExerciseType.weightReps;
  const b = ExerciseType.bodyweight;
  const t = ExerciseType.timed;
  final last = [s(1, w: 60, r: 10), s(2, w: 62.5, r: 8), s(3, w: 62.5, r: 6)];

  final cases =
      <(String, ExerciseType, List<SetEntry>, List<SetEntry>, SetValues)>[
        // Rule 1: previous set of this session
        (
          'set n−1 of this session',
          w,
          [s(1, w: 65, r: 9)],
          last,
          const SetValues(weightKg: 65, reps: 9),
        ),
        // Rule 2: set n of the last session, otherwise its last set
        (
          'set 1 from last session',
          w,
          [],
          last,
          const SetValues(weightKg: 60, reps: 10),
        ),
        (
          'warm-up sets are ignored',
          w,
          [s(9, w: 20, r: 15, warmup: true)],
          last,
          const SetValues(weightKg: 60, reps: 10),
        ),
        (
          'last set when the last session had fewer sets',
          w,
          [],
          [s(1, w: 50, r: 12)],
          const SetValues(weightKg: 50, reps: 12),
        ),
        // Rule 3: targets, weight empty / 0
        ('weight_reps without history', w, [], [], const SetValues(reps: 10)),
        (
          'bodyweight without history',
          b,
          [],
          [],
          const SetValues(weightKg: 0, reps: 10),
        ),
        ('timed without history', t, [], [], const SetValues(durationSec: 45)),
        (
          'bodyweight keeps added weight',
          b,
          [s(1, w: 10, r: 8)],
          [],
          const SetValues(weightKg: 10, reps: 8),
        ),
        (
          'timed from last session with added weight',
          t,
          [],
          [s(1, d: 60, w: 5)],
          const SetValues(durationSec: 60, weightKg: 5),
        ),
      ];

  for (final (name, type, current, lastSets, expected) in cases) {
    test(name, () {
      expect(
        prefillSet(
          type: type,
          currentSets: current,
          lastSessionSets: lastSets,
          targetReps: 10,
          targetDurationSec: 45,
        ),
        expected,
      );
    });
  }

  test('set 2 uses set 1 of this session, not set 2 of the last one', () {
    expect(
      prefillSet(
        type: w,
        currentSets: [s(1, w: 60, r: 10)],
        lastSessionSets: last,
      ),
      const SetValues(weightKg: 60, reps: 10),
    );
  });

  test('without target and history the reps stay empty', () {
    expect(
      prefillSet(type: w, currentSets: const [], lastSessionSets: const []),
      const SetValues(),
    );
  });
}
