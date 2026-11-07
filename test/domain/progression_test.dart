import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/progression.dart';
import 'package:gymlog/domain/weight_steps.dart';

SetEntry s({double? w, int? r, int? d, bool warmup = false}) => SetEntry(
  id: 1,
  sessionExerciseId: 1,
  setIndex: 1,
  weightKg: w,
  reps: r,
  durationSec: d,
  isWarmup: warmup,
  completedAt: DateTime.utc(2026),
);

ProgressionSuggestion? suggest(
  ExerciseType type,
  List<SetEntry> last, {
  int sets = 3,
  int? reps = 10,
  int? duration = 45,
  WeightStep step = const KgStep(2.5),
}) => suggestProgression(
  type: type,
  step: step,
  targetSets: sets,
  targetReps: reps,
  targetDurationSec: duration,
  lastSessionSets: last,
);

void main() {
  const w = ExerciseType.weightReps;
  const b = ExerciseType.bodyweight;
  const t = ExerciseType.timed;
  final hit = [s(w: 60, r: 10), s(w: 60, r: 10), s(w: 60, r: 11)];

  test('all target sets reached → +increment', () {
    final p = suggest(w, hit);
    expect(p, isA<AddWeight>());
    expect(
      p!.applyTo(const SetValues(weightKg: 60, reps: 10)),
      const SetValues(weightKg: 62.5, reps: 10),
    );
  });

  test('lbs plates and levels: the next plate / level (1.1.0)', () {
    final hit45 = [s(w: 45, r: 10), s(w: 45, r: 10), s(w: 45, r: 10)];
    final plates = suggest(w, hit45, step: const LbsStep(15))! as AddWeight;
    expect(
      plates.applyTo(const SetValues(weightKg: 45, reps: 10)).weightKg,
      52,
    );
    expect(plates.deltaFrom(45), 7);
    expect(plates.deltaFrom(52), 7);
    expect(plates.deltaFrom(73), 6);
    final levels = suggest(w, hit45, step: const LevelStep(4.5))! as AddWeight;
    expect(
      levels.applyTo(const SetValues(weightKg: 45, reps: 10)).weightKg,
      49.5,
    );
  });

  final none = <(String, ExerciseType, List<SetEntry>, int, int?, int?)>[
    (
      'one set missed the target',
      w,
      [s(w: 60, r: 10), s(w: 60, r: 9), s(w: 60, r: 10)],
      3,
      10,
      45,
    ),
    (
      'fewer sets than the target',
      w,
      [s(w: 60, r: 10), s(w: 60, r: 10)],
      3,
      10,
      45,
    ),
    ('no reps target', w, hit, 3, null, 45),
    ('no history', w, <SetEntry>[], 3, 10, 45),
    ('no duration target', t, [s(d: 60)], 1, 10, null),
    (
      'warm-ups do not count as sets',
      w,
      [s(w: 60, r: 10), s(w: 20, r: 10, warmup: true)],
      2,
      10,
      45,
    ),
  ];
  for (final (name, type, last, sets, reps, duration) in none) {
    test('no suggestion: $name', () {
      expect(
        suggest(type, last, sets: sets, reps: reps, duration: duration),
        isNull,
      );
    });
  }

  test('bodyweight without added weight → +1 rep', () {
    final p = suggest(b, [s(w: 0, r: 10), s(w: 0, r: 12), s(w: 0, r: 10)]);
    expect(p, isA<AddRep>());
    expect(
      p!.applyTo(const SetValues(weightKg: 0, reps: 10)),
      const SetValues(weightKg: 0, reps: 11),
    );
  });

  test('bodyweight with added weight → +increment', () {
    final p = suggest(b, [s(w: 5, r: 10), s(w: 5, r: 10), s(w: 5, r: 10)]);
    expect(p, isA<AddWeight>());
  });

  test('timed → +5 s', () {
    final p = suggest(t, [s(d: 45), s(d: 50), s(d: 45)]);
    expect(p, isA<AddDuration>());
    expect(
      p!.applyTo(const SetValues(durationSec: 45)),
      const SetValues(durationSec: 50),
    );
  });
}
