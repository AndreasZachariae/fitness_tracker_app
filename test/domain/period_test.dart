import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/local_date.dart';
import 'package:gymlog/domain/period.dart';

void main() {
  final today = LocalDate(2026, 11, 3);
  final cases = <(StatsPeriod, LocalDate?)>[
    (StatsPeriod.fourWeeks, LocalDate(2026, 10, 7)),
    (StatsPeriod.threeMonths, LocalDate(2026, 8, 4)),
    (StatsPeriod.oneYear, LocalDate(2025, 11, 4)),
    (StatsPeriod.all, null),
  ];
  for (final (period, start) in cases) {
    test('${period.name} starts $start', () {
      expect(period.startFor(today), start);
    });
  }

  test('month arithmetic clamps to the month end', () {
    expect(
      StatsPeriod.threeMonths.startFor(LocalDate(2026, 5, 31)),
      LocalDate(2026, 3, 1),
    );
    expect(
      StatsPeriod.oneYear.startFor(LocalDate(2028, 2, 29)),
      LocalDate(2027, 3, 1),
    );
  });

  test('contains: inclusive start, nothing in the future', () {
    expect(
      StatsPeriod.fourWeeks.contains(LocalDate(2026, 10, 7), today),
      isTrue,
    );
    expect(
      StatsPeriod.fourWeeks.contains(LocalDate(2026, 10, 6), today),
      isFalse,
    );
    expect(StatsPeriod.all.contains(LocalDate(2000, 1, 1), today), isTrue);
    expect(StatsPeriod.all.contains(LocalDate(2026, 11, 4), today), isFalse);
  });
}
