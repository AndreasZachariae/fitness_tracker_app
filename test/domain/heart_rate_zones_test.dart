import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/heart_rate.dart';
import 'package:gymlog/domain/heart_rate_zones.dart';
import 'package:gymlog/domain/models/models.dart';

/// 1.6.0: zones, load, calories, recovery, cardio targets; 1.6.1: zones
/// after the lactate threshold heart rate (Garmin %LSHF).
void main() {
  test('Garmin %LSHF zones of a threshold of 170', () {
    // 57/67/79/90/101 % up to 113 %.
    expect(heartRateZones(170).map((z) => (z.number, z.from, z.to)), [
      (1, 97, 113),
      (2, 114, 133),
      (3, 134, 152),
      (4, 153, 171),
      (5, 172, 192),
    ]);
    expect(zoneOf(96, 170), 0);
    expect(zoneOf(97, 170), 1);
    expect(zoneOf(133, 170), 2);
    expect(zoneOf(134, 170), 3);
    expect(zoneOf(210, 170), 5);
    // Pause: end of zone 1; warning: 107 %.
    expect((defaultPauseBpm(170), defaultWarnBpm(170)), (113, 182));
    // The zones close without gaps for every allowed threshold.
    for (var t = 80; t <= 230; t++) {
      final zones = heartRateZones(t);
      for (var i = 1; i < 5; i++) {
        expect(zones[i].from, zones[i - 1].to + 1, reason: 'threshold $t');
      }
    }
  });

  test('time in zones and Edwards TRIMP', () {
    final histogram = {90: 60, 100: 120, 150: 30};
    expect(secondsPerZone(histogram, 170), {
      0: 60,
      1: 120,
      2: 0,
      3: 30,
      4: 0,
      5: 0,
    });
    // 2 min × 1 + 0,5 min × 3.
    expect(edwardsTrimp(histogram, 170), closeTo(3.5, 1e-9));
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
    // With a threshold of 170 only set 1 counts (120 below zone 3).
    expect(heartRateRecovery(samples, windows, threshold: 170), 30);
    // Without a profile both: (30 + 20) / 2.
    expect(heartRateRecovery(samples, windows), 25);
    // No value about 60 s later: nothing.
    expect(heartRateRecovery([at(100, 160)], [window(60, 120)]), isNull);
    expect(heartRateRecovery(const [], windows), isNull);
  });

  test('1.6.1 recovery: late peak of a wrist sensor, interrupted minute', () {
    // The watch lags: the peak comes 30 s after the set (completed at 100).
    final late = [at(100, 140), at(130, 165), at(190, 135)];
    expect(heartRateRecovery(late, [window(60, 120)]), 30);
    // Next set starts 40 s after the peak: no clean minute, not counted.
    final windows = [window(60, 120), window(150, 210)];
    expect(heartRateRecovery(late, windows), isNull);
    // Still rising a minute later: the peak was not reached, not counted.
    final rising = [at(100, 120), at(145, 125), at(205, 150)];
    expect(heartRateRecovery(rising, [window(60, 120)]), isNull);
  });

  test('cardio target: zone inside, bpm at least', () {
    expect(inTarget(115, zone: 2, threshold: 170), isTrue);
    expect(inTarget(135, zone: 2, threshold: 170), isFalse);
    expect(inTarget(120, targetBpm: 120), isTrue);
    expect(inTarget(119, targetBpm: 120), isFalse);
    expect(inTarget(120, zone: 2), isFalse, reason: 'zone without profile');

    final samples = [
      for (var s = 0; s < 10; s++) at(s, 100), // zone 1
      for (var s = 10; s < 30; s++) at(s, 115), // zone 2
      for (var s = 30; s < 40; s++) at(s, 140), // zone 3
    ];
    expect(
      secondsInTarget(
        samples,
        from: start,
        to: start.add(const Duration(seconds: 40)),
        zone: 2,
        threshold: 170,
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
