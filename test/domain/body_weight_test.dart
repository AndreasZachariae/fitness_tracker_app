import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/body_weight.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/period.dart';

BodyWeightEntry e(String date, double kg) => BodyWeightEntry(
  id: 0,
  date: LocalDate.parse(date),
  weightKg: kg,
  createdAt: DateTime.utc(2026),
);

void main() {
  group('movingAverage7 (SPEC §7.8)', () {
    test('mean of all entries in [d − 6, d]', () {
      final r = movingAverage7([
        e('2026-11-08', 82), // window 2.–8.: 80, 81, 82 → 81
        e('2026-11-01', 79), // alone
        e('2026-11-02', 80), // 1.–2. → 79.5
        e('2026-11-05', 81), // 1.–5. → 80
      ]);
      expect(r.map((s) => s.entry.date.toIsoString()), [
        '2026-11-01',
        '2026-11-02',
        '2026-11-05',
        '2026-11-08',
      ]);
      expect(r.map((s) => s.average), [79, 79.5, 80, 81]);
    });

    test('gaps longer than a week reset the window', () {
      final r = movingAverage7([e('2026-10-01', 90), e('2026-10-20', 80)]);
      expect(r.last.average, 80);
    });

    test('exactly 6 days back is included, 7 is not', () {
      expect(
        movingAverage7([e('2026-11-01', 80), e('2026-11-07', 82)]).last.average,
        81,
      );
      expect(
        movingAverage7([e('2026-11-01', 80), e('2026-11-08', 82)]).last.average,
        82,
      );
    });

    test('empty', () => expect(movingAverage7(const []), isEmpty));
  });

  group('bodyWeightStats', () {
    final today = LocalDate(2026, 11, 3);
    final data = movingAverage7([
      e('2026-09-01', 84),
      e('2026-10-01', 83),
      e('2026-10-03', 82),
      e('2026-11-01', 81),
      e('2026-11-03', 80),
    ]);

    test('current, change over 30 days, min/max in period', () {
      final s = bodyWeightStats(data, StatsPeriod.fourWeeks, today);
      expect(s.current, 80.5);
      // Latest entry ≤ 4.10.: 3.10. with average (83 + 82) / 2 = 82.5
      expect(s.change30Days, closeTo(-2, 1e-9));
      expect((s.min, s.max), (80, 81));
      final all = bodyWeightStats(data, StatsPeriod.all, today);
      expect((all.min, all.max), (80, 84));
    });

    test('no change without an entry 30 days earlier', () {
      final s = bodyWeightStats(
        movingAverage7([e('2026-11-01', 81)]),
        StatsPeriod.all,
        today,
      );
      expect(s.change30Days, isNull);
      expect(s.current, 81);
    });

    test('empty data', () {
      final s = bodyWeightStats(const [], StatsPeriod.all, today);
      expect(
        (s.current, s.change30Days, s.min, s.max),
        (null, null, null, null),
      );
    });
  });
}
