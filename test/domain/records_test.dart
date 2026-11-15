import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/records.dart';

int _id = 0;
HistorySet h(int session, {double? w, int? r, int? d, bool warmup = false}) => (
  set: SetEntry(
    id: ++_id,
    sessionExerciseId: session,
    setIndex: 1,
    weightKg: w,
    reps: r,
    durationSec: d,
    isWarmup: warmup,
    completedAt: DateTime.utc(2026),
  ),
  sessionId: session,
);

void main() {
  group('estimatedOneRepMax (Epley)', () {
    final cases = <(double, int, double?)>[
      (100, 1, 100),
      (100, 10, 100 * (1 + 10 / 30)),
      (60, 5, 70),
      (0, 5, null),
      (-10, 5, null),
      (100, 0, null),
    ];
    for (final (w, r, expected) in cases) {
      test('$w × $r → $expected', () {
        final v = estimatedOneRepMax(w, r);
        expected == null
            ? expect(v, isNull)
            : expect(v, closeTo(expected, 1e-9));
      });
    }
  });

  test('record kinds per type (SPEC §7.7)', () {
    expect(recordKindsFor(ExerciseType.weightReps), [
      RecordKind.estimatedOneRepMax,
      RecordKind.weight,
    ]);
    expect(recordKindsFor(ExerciseType.bodyweight), [
      RecordKind.reps,
      RecordKind.addedWeight,
    ]);
    expect(recordKindsFor(ExerciseType.timed), [RecordKind.duration]);
  });

  group('1.6.3 exercise record', () {
    test('totals: volume, reps, time; warm-ups do not count', () {
      expect(
        exerciseTotal(ExerciseType.weightReps, [
          h(1, w: 60, r: 10).set,
          h(1, w: 60, r: 8).set,
          h(1, w: 20, r: 10, warmup: true).set,
        ]),
        1080,
      );
      expect(
        exerciseTotal(ExerciseType.bodyweight, [
          h(1, w: 0, r: 12).set,
          h(1, w: 5, r: 8).set,
        ]),
        20,
      );
      expect(
        exerciseTotal(ExerciseType.timed, [h(1, d: 60).set, h(1, d: 45).set]),
        105,
      );
    });

    test('status against the trainings before; first never a record', () {
      final hist = [
        h(1, w: 60, r: 10), // 600
        h(2, w: 60, r: 10), h(2, w: 60, r: 10), // 1200
        h(3, w: 60, r: 10), // 600
        h(4, w: 70, r: 10), h(4, w: 60, r: 10), // 1300
      ];
      final first = exerciseRecordStatus(ExerciseType.weightReps, hist, 1);
      expect((first.total, first.best, first.isRecord), (600, null, false));
      final third = exerciseRecordStatus(ExerciseType.weightReps, hist, 3);
      expect((third.total, third.best, third.isRecord), (600, 1200, false));
      expect(third.missing, 600);
      final fourth = exerciseRecordStatus(ExerciseType.weightReps, hist, 4);
      expect((fourth.best, fourth.isRecord, fourth.missing), (1200, true, 0));
      // A training without sets yet compares with all.
      final next = exerciseRecordStatus(ExerciseType.weightReps, hist, 9);
      expect((next.total, next.best), (0, 1300));
      expect(exerciseRecordSessions(ExerciseType.weightReps, hist), {2, 4});
      // Equal is no record.
      expect(
        exerciseRecordSessions(ExerciseType.timed, [h(1, d: 60), h(2, d: 60)]),
        isEmpty,
      );
    });
  });

  test('bestValues per kind', () {
    final sets = [h(1, w: 60, r: 10).set, h(2, w: 70, r: 3).set];
    final best = bestValues(ExerciseType.weightReps, sets);
    expect(best[RecordKind.weight]!.value, 70);
    expect(best[RecordKind.estimatedOneRepMax]!.value, closeTo(80, 1e-9));
  });
}
