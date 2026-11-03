import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/format/exercise_format.dart';
import 'package:gymlog/domain/models/models.dart';

SetEntry s(int i, {double? w, int? r, int? d}) => SetEntry(
  id: i,
  sessionExerciseId: 1,
  setIndex: i,
  weightKg: w,
  reps: r,
  durationSec: d,
  isWarmup: false,
  completedAt: DateTime.utc(2026),
);

void main() {
  test('formatDuration', () {
    expect(formatDuration(45), '45 s');
    expect(formatDuration(60), '1:00 min');
    expect(formatDuration(90), '1:30 min');
  });

  test('formatSignedKg uses a real minus sign', () {
    expect(formatSignedKg(0), '+0 kg');
    expect(formatSignedKg(10), '+10 kg');
    expect(formatSignedKg(-20), '−20 kg');
    expect(formatSignedKg(2.5), '+2,5 kg');
  });

  const w = ExerciseType.weightReps;
  const b = ExerciseType.bodyweight;
  const t = ExerciseType.timed;

  final targets = <(ExerciseType, int, int?, int?, String)>[
    (w, 3, 10, null, '3 × 10'),
    (w, 3, null, null, '3 Sätze'),
    (w, 1, null, null, '1 Satz'),
    (b, 4, 8, null, '4 × 8'),
    (t, 3, null, 45, '3 × 45 s'),
    (t, 2, null, 90, '2 × 1:30 min'),
    (t, 3, 10, null, '3 Sätze'),
  ];
  for (final (type, sets, reps, duration, expected) in targets) {
    test('formatTarget → $expected', () {
      expect(
        formatTarget(type, sets: sets, reps: reps, durationSec: duration),
        expected,
      );
    });
  }

  final summaries = <(ExerciseType, List<SetEntry>, String)>[
    (
      w,
      [s(1, w: 60, r: 10), s(2, w: 60, r: 10), s(3, w: 60, r: 8)],
      '60 kg × 10, 10, 8',
    ),
    (w, [s(1, w: 60, r: 10), s(2, w: 62.5, r: 8)], '60 × 10, 62,5 × 8'),
    (b, [s(1, w: 0, r: 10), s(2, w: 0, r: 9)], '10, 9 Wdh'),
    (b, [s(1, w: 10, r: 8), s(2, w: 10, r: 7)], '+10 kg × 8, 7'),
    (b, [s(1, w: -20, r: 8)], '−20 kg × 8'),
    (b, [s(1, w: 0, r: 10), s(2, w: 5, r: 8)], '+0 × 10, +5 × 8'),
    (t, [s(1, d: 45), s(2, d: 40)], '45, 40 s'),
    (t, [s(1, d: 90), s(2, d: 55)], '1:30, 0:55 min'),
    (w, <SetEntry>[], ''),
  ];
  for (final (type, sets, expected) in summaries) {
    test('formatSetsSummary → "$expected"', () {
      expect(formatSetsSummary(type, sets), expected);
    });
  }
}
