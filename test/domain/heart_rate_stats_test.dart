import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/statistics.dart';

/// 1.6.0: recovery, weekly load and calories in the statistics.
void main() {
  Training training(int id, DateTime start) => Training(
    session: Session(
      id: id,
      planId: null,
      planNameSnapshot: null,
      startedAt: start,
      endedAt: start.add(const Duration(hours: 1)),
      notes: '',
    ),
    exercises: const [],
  );
  SessionHeartRate hr(int id, {int? recovery}) => SessionHeartRate(
    sessionId: id,
    avgBpm: 140,
    maxBpm: 170,
    minBpm: 90,
    seconds: 3600,
    // 30 min in range 1 and 30 min in range 4 (maximum 185).
    histogram: '100:1800,150:1800',
    curve: '',
    recoveryBpm: recovery,
  );
  final mon = DateTime.utc(2026, 10, 19, 17);
  final data = StatsData(
    trainings: [
      training(1, mon),
      training(2, mon.add(const Duration(days: 2))),
      training(3, mon.add(const Duration(days: 14))),
      training(4, mon.add(const Duration(days: 15))),
    ],
    bodyWeights: [
      BodyWeightEntry(
        id: 1,
        date: LocalDate(2026, 10, 1),
        weightKg: 80,
        createdAt: mon,
      ),
    ],
    exercises: const [],
    heartRates: {1: hr(1, recovery: 30), 2: hr(2), 3: hr(3, recovery: 34)},
  );
  final today = LocalDate(2026, 11, 3);

  test('recovery per training, only where there is one', () {
    expect(trainingRecoveries(data).map((p) => (p.day, p.value)), [
      (LocalDate(2026, 10, 19), 30.0),
      (LocalDate(2026, 11, 2), 34.0),
    ]);
  });

  test('weekly load: TRIMP per week, empty weeks included', () {
    // One training: 30 × 1 + 30 × 4 = 150.
    final weeks = weeklyLoad(data, today, 185);
    expect(weeks.map((w) => (w.monday, w.value)), [
      (LocalDate(2026, 10, 19), 300.0),
      (LocalDate(2026, 10, 26), 0.0),
      (LocalDate(2026, 11, 2), 150.0),
    ]);
  });

  test('weekly calories need the profile', () {
    final profile = AppSettings.defaults.copyWith(
      birthYear: 1990,
      sex: Sex.male,
    );
    final weeks = weeklyCalories(data, today, profile);
    // 809 kcal per training (see heart_rate_ranges_test).
    expect(weeks.map((w) => w.value), [1618.0, 0.0, 809.0]);
    expect(weeklyCalories(data, today, AppSettings.defaults), isEmpty);
  });
}
