import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/heart_rate.dart';
import 'package:gymlog/domain/heart_rate_ranges.dart';
import 'package:gymlog/domain/models/models.dart';

/// 1.6.0: Garmin ranges, load, calories, recovery, cardio targets.
void main() {
  test('Garmin ranges of a maximum of 185', () {
    expect(garminRanges(185).map((r) => (r.number, r.from, r.to)), [
      (1, 93, 110),
      (2, 111, 129),
      (3, 130, 147),
      (4, 148, 166),
      (5, 167, 185),
    ]);
    expect(rangeOf(92, 185), 0);
    expect(rangeOf(93, 185), 1);
    expect(rangeOf(129, 185), 2);
    expect(rangeOf(130, 185), 3);
    expect(rangeOf(200, 185), 5);
    expect((defaultPauseBpm(185), defaultWarnBpm(185)), (111, 176));
  });

  test('time in ranges and Edwards TRIMP', () {
    final histogram = {90: 60, 100: 120, 150: 30};
    expect(secondsPerRange(histogram, 185), {
      0: 60,
      1: 120,
      2: 0,
      3: 0,
      4: 30,
      5: 0,
    });
    // 2 min × 1 + 0,5 min × 4.
    expect(edwardsTrimp(histogram, 185), closeTo(4, 1e-9));
  });

  test('calories by Keytel', () {
    int? kcal(Sex? sex, {double? weight = 80, int? age = 36}) => caloriesKeytel(
      averageBpm: 140,
      seconds: 3600,
      weightKg: weight,
      age: age,
      sex: sex,
    );
    expect(kcal(Sex.male), 809);
    expect(kcal(Sex.female), 499);
    expect(kcal(null), isNull);
    expect(kcal(Sex.male, weight: null), isNull);
    expect(kcal(Sex.male, age: null), isNull);
    expect(ageAt(1990, DateTime.utc(2026, 11, 3)), 36);
  });

  final start = DateTime.utc(2026, 11, 3, 17);
  var id = 0;
  HeartRateSample at(int seconds, int bpm) => HeartRateSample(
    id: ++id,
    sessionId: 1,
    recordedAt: start.add(Duration(seconds: seconds)),
    bpm: bpm,
  );
  SetWindow window(int from, int to) => (
    start: start.add(Duration(seconds: from)),
    end: start.add(Duration(seconds: to)),
    completedAt: start.add(Duration(seconds: to - 20)),
  );

  test('heart rate recovery: drop 60 s after the peak of hard sets', () {
    final samples = [
      at(90, 150),
      at(100, 160), // peak of set 1
      at(160, 130), // 60 s later: −30
      at(390, 115),
      at(400, 120), // peak of set 2 (easy)
      at(460, 100), // −20
    ];
    final windows = [window(60, 120), window(360, 420)];
    // With a maximum of 185 only set 1 counts (120 < 70 %).
    expect(heartRateRecovery(samples, windows, hrMax: 185), 30);
    // Without a profile both: (30 + 20) / 2.
    expect(heartRateRecovery(samples, windows), 25);
    // No value about 60 s later: nothing.
    expect(heartRateRecovery([at(100, 160)], [window(60, 120)]), isNull);
    expect(heartRateRecovery(const [], windows), isNull);
  });

  test('cardio target: range inside, bpm at least', () {
    expect(inTarget(115, range: 2, hrMax: 185), isTrue);
    expect(inTarget(135, range: 2, hrMax: 185), isFalse);
    expect(inTarget(120, targetBpm: 120), isTrue);
    expect(inTarget(119, targetBpm: 120), isFalse);
    expect(inTarget(120, range: 2), isFalse, reason: 'range without maximum');

    final samples = [
      for (var s = 0; s < 10; s++) at(s, 100), // below range 2
      for (var s = 10; s < 30; s++) at(s, 115), // range 2
      for (var s = 30; s < 40; s++) at(s, 140), // range 3
    ];
    expect(
      secondsInTarget(
        samples,
        from: start,
        to: start.add(const Duration(seconds: 40)),
        range: 2,
        hrMax: 185,
      ),
      20,
    );
    expect(
      secondsInTarget(
        samples,
        from: start,
        to: start.add(const Duration(seconds: 40)),
        targetBpm: 115,
      ),
      30,
    );
  });
}
