import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/history.dart';
import 'package:gymlog/domain/models/models.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3, 18);
  final cases = <(String, DateTime, DateTime, SessionTimesError?)>[
    (
      'valid',
      DateTime.utc(2026, 11, 3, 16),
      DateTime.utc(2026, 11, 3, 17),
      null,
    ),
    (
      'end = start',
      DateTime.utc(2026, 11, 3, 16),
      DateTime.utc(2026, 11, 3, 16),
      SessionTimesError.endBeforeStart,
    ),
    (
      'end before start',
      DateTime.utc(2026, 11, 3, 17),
      DateTime.utc(2026, 11, 3, 16),
      SessionTimesError.endBeforeStart,
    ),
    (
      'end in future',
      DateTime.utc(2026, 11, 3, 17),
      DateTime.utc(2026, 11, 3, 19),
      SessionTimesError.inFuture,
    ),
    ('end exactly now', DateTime.utc(2026, 11, 3, 17), now, null),
  ];
  for (final (name, start, end, expected) in cases) {
    test('validateSessionTimes: $name', () {
      expect(validateSessionTimes(start: start, end: end, now: now), expected);
    });
  }

  test('groupByMonth keeps order and splits at local month changes', () {
    final items = [
      DateTime(2026, 11, 3, 18),
      DateTime(2026, 11, 1, 9),
      DateTime(2026, 10, 31, 23, 30),
      DateTime(2025, 10, 2),
    ];
    final groups = groupByMonth(items, (d) => d);
    expect(groups.map((g) => g.$1), [
      DateTime(2026, 11),
      DateTime(2026, 10),
      DateTime(2025, 10),
    ]);
    expect(groups.map((g) => g.$2.length), [2, 1, 1]);
  });

  test('planVolumeChanges: against the previous training of the same plan '
      '(1.3.1)', () {
    Session session(int id, int? plan, int day) => Session(
      id: id,
      planId: plan,
      planNameSnapshot: plan == null ? null : 'Plan $plan',
      startedAt: DateTime.utc(2026, 11, day, 17),
      endedAt: DateTime.utc(2026, 11, day, 18),
      notes: '',
    );
    final sessions = [
      session(5, 1, 9), // newest first, like the history
      session(4, 2, 7),
      session(3, null, 6),
      session(2, 1, 5),
      session(1, 1, 2),
      session(6, 2, 3),
    ];
    final volume = {1: 1000.0, 2: 1100.0, 5: 990.0, 6: 0.0, 4: 500.0};
    final changes = planVolumeChanges(sessions, volume);
    expect(changes.keys.toSet(), {2, 5});
    expect(changes[2], closeTo(10, 1e-9));
    expect(changes[5], closeTo(-10, 1e-9));
    // 4 follows a training without volume: no percentage.
    expect(changes.containsKey(4), isFalse);
  });
}
