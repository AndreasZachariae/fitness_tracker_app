import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/calendar.dart';
import 'package:gymlog/domain/models/local_date.dart';

void main() {
  final cases = <(String, IsoWeek)>[
    ('2026-11-03', const IsoWeek(2026, 45)),
    ('2026-01-01', const IsoWeek(2026, 1)), // Thursday
    ('2025-12-29', const IsoWeek(2026, 1)), // Monday of 2026-W01
    ('2025-12-28', const IsoWeek(2025, 52)), // Sunday
    ('2026-12-31', const IsoWeek(2026, 53)), // Thursday, 53-week year
    ('2027-01-03', const IsoWeek(2026, 53)), // Sunday
    ('2027-01-04', const IsoWeek(2027, 1)), // Monday
    ('2021-01-03', const IsoWeek(2020, 53)),
    ('2024-12-30', const IsoWeek(2025, 1)),
  ];
  for (final (day, week) in cases) {
    test('$day → $week', () {
      expect(IsoWeek.of(LocalDate.parse(day)), week);
    });
  }

  test('mondayOf and weeksBetween across the year boundary', () {
    expect(mondayOf(LocalDate(2027, 1, 3)), LocalDate(2026, 12, 28));
    expect(mondayOf(LocalDate(2026, 11, 2)), LocalDate(2026, 11, 2));
    expect(weeksBetween(LocalDate(2026, 12, 31), LocalDate(2027, 1, 4)), 1);
    expect(weeksBetween(LocalDate(2026, 11, 2), LocalDate(2026, 11, 8)), 0);
    expect(weeksBetween(LocalDate(2026, 9, 1), LocalDate(2026, 11, 3)), 9);
  });

  test('ordering', () {
    expect(
      const IsoWeek(2026, 53).compareTo(const IsoWeek(2027, 1)),
      lessThan(0),
    );
  });
}
