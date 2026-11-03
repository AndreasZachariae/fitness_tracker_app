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

  group('detectRecords', () {
    test('no records in the very first session', () {
      final hist = [h(1, w: 60, r: 10), h(1, w: 70, r: 10), h(1, w: 80, r: 5)];
      expect(detectRecords(ExerciseType.weightReps, hist), isEmpty);
    });

    test('strictly greater than all earlier sets, incl. the same session', () {
      final a = h(1, w: 60, r: 10); // e1RM 80
      final b = h(2, w: 60, r: 10); // equal → no record
      final c = h(2, w: 62.5, r: 8); // weight 62.5 > 60, e1RM 79.2 < 80
      final d = h(2, w: 62.5, r: 10); // e1RM 83.3 > 80, weight equal
      final e = h(2, w: 65, r: 10); // both
      final r = detectRecords(ExerciseType.weightReps, [a, b, c, d, e]);
      expect(r.containsKey(b.set.id), isFalse);
      expect(r[c.set.id], [RecordKind.weight]);
      expect(r[d.set.id], [RecordKind.estimatedOneRepMax]);
      expect(r[e.set.id], [RecordKind.estimatedOneRepMax, RecordKind.weight]);
    });

    test('warm-up sets are ignored', () {
      final r = detectRecords(ExerciseType.weightReps, [
        h(1, w: 60, r: 10),
        h(2, w: 100, r: 10, warmup: true),
        h(2, w: 61, r: 10),
      ]);
      expect(r.values.single, [
        RecordKind.estimatedOneRepMax,
        RecordKind.weight,
      ]);
    });

    test('bodyweight: reps and added weight separately', () {
      final r = detectRecords(ExerciseType.bodyweight, [
        h(1, w: 0, r: 8),
        h(2, w: 0, r: 9),
        h(3, w: 5, r: 6),
      ]);
      expect(r.values.toList(), [
        [RecordKind.reps],
        [RecordKind.addedWeight],
      ]);
    });

    test('timed: longest duration', () {
      final r = detectRecords(ExerciseType.timed, [
        h(1, d: 60),
        h(2, d: 60),
        h(3, d: 65),
      ]);
      expect(r.values.single, [RecordKind.duration]);
    });
  });

  test('bestValues per kind', () {
    final sets = [h(1, w: 60, r: 10).set, h(2, w: 70, r: 3).set];
    final best = bestValues(ExerciseType.weightReps, sets);
    expect(best[RecordKind.weight]!.value, 70);
    expect(best[RecordKind.estimatedOneRepMax]!.value, closeTo(80, 1e-9));
  });
}
