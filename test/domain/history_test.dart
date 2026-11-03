import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/history.dart';

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
}
