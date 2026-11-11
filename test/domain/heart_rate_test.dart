import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/heart_rate.dart';
import 'package:gymlog/domain/models/models.dart';

/// 1.5.0/1.5.1: Bluetooth heart rate measurement and what is kept of it.
void main() {
  group('parseHeartRateReading (0x2A37)', () {
    test('8 and 16 bit values', () {
      expect(parseHeartRateMeasurement([0x00, 72]), 72);
      expect(parseHeartRateMeasurement([0x01, 0x2C, 0x00]), 44);
      expect(parseHeartRateMeasurement([0x01, 0xC8, 0x00, 0x10, 0x03]), 200);
    });

    test('RR intervals (flag 0x10, after an optional energy value)', () {
      expect(parseHeartRateReading([0x00, 72]), (bpm: 72, hasRr: false));
      expect(parseHeartRateReading([0x10, 130, 0x20, 0x03]), (
        bpm: 130,
        hasRr: true,
      ));
      // Flag set, but no bytes: none.
      expect(parseHeartRateReading([0x10, 130])?.hasRr, isFalse);
      // 16 bit value and energy expended before the RR intervals.
      expect(
        parseHeartRateReading([0x19, 0x80, 0x00, 0x01, 0x02, 0x20, 0x03]),
        (bpm: 128, hasRr: true),
      );
      expect(parseHeartRateReading([0x19, 0x80, 0x00, 0x01, 0x02]), (
        bpm: 128,
        hasRr: false,
      ));
    });

    test('skin contact', () {
      expect(parseHeartRateMeasurement([0x06, 95]), 95);
      expect(parseHeartRateMeasurement([0x04, 95]), isNull);
      expect(parseHeartRateMeasurement([0x02, 95]), 95);
    });

    test('broken or implausible', () {
      expect(parseHeartRateMeasurement([]), isNull);
      expect(parseHeartRateMeasurement([0x00]), isNull);
      expect(parseHeartRateMeasurement([0x01, 0x50]), isNull);
      expect(parseHeartRateMeasurement([0x00, 0]), isNull);
      expect(parseHeartRateMeasurement([0x00, 19]), isNull);
      expect(parseHeartRateMeasurement([0x01, 0x00, 0x01]), isNull);
    });
  });

  final start = DateTime.utc(2026, 11, 3, 17);
  var nextId = 0;
  HeartRateSample at(int seconds, int bpm) => HeartRateSample(
    id: ++nextId,
    sessionId: 1,
    recordedAt: start.add(Duration(seconds: seconds)),
    bpm: bpm,
  );

  test('stats (1.5.0)', () {
    expect(heartRateStats(const []), isNull);
    final s = heartRateStats([at(0, 90), at(5, 120), at(10, 151)])!;
    expect((s.average, s.max, s.min, s.count), (120, 151, 90, 3));
  });

  group('summary of a training (1.5.1)', () {
    test('time-weighted, distribution, curve per minute', () {
      final samples = [
        // Minute 0: 100 for 10 s, then 120 for 5 s.
        for (var s = 0; s < 10; s++) at(s, 100),
        for (var s = 10; s < 15; s++) at(s, 120),
        // A gap of a minute (monitor lost) counts 5 s at most.
        at(130, 150),
        at(131, 150),
      ];
      final sum = summarizeHeartRate(samples, start)!;
      expect((sum.max, sum.min), (150, 100));
      // 100 × 10 s + 120 × (4 + 5) s + 150 × 2 s.
      expect(sum.histogram, {100: 10, 120: 9, 150: 2});
      expect(sum.seconds, 21);
      expect(sum.average, ((1000 + 1080 + 300) / 21).round());
      expect(sum.curve, [107, null, 150]);
      expect(summarizeHeartRate(const [], start), isNull);
    });

    test('set and exercise windows', () {
      final completed = start.add(const Duration(minutes: 5));
      // Other set: the minute before; a timed set: its duration.
      final w = setWindow(completedAt: completed);
      expect(w.start, completed.subtract(const Duration(seconds: 60)));
      expect(w.end, completed.add(const Duration(seconds: 20)));
      expect(
        setWindow(completedAt: completed, durationSec: 30).start,
        completed.subtract(const Duration(seconds: 30)),
      );
      // Not before the previous set.
      expect(
        setWindow(
          completedAt: completed,
          previousCompletedAt: completed.subtract(const Duration(seconds: 40)),
        ).start,
        completed.subtract(const Duration(seconds: 40)),
      );

      final samples = [
        at(230, 90), // before the window
        at(250, 110),
        at(290, 130),
        at(300, 140), // the set ends at 300 s
        at(315, 155), // peak after the set
        at(330, 99), // after the window
      ];
      expect(setHeartRate(samples, w), (average: 127, peak: 155));
      expect(setHeartRate(const [], w), isNull);

      SetEntry set(int id, int seconds) => SetEntry(
        id: id,
        sessionExerciseId: 1,
        setIndex: id,
        weightKg: 60,
        reps: 10,
        durationSec: null,
        isWarmup: false,
        completedAt: start.add(Duration(seconds: seconds)),
      );
      expect(
        exerciseHeartRate(samples, [set(1, 300), set(2, 200)]),
        // From 140 s (first set's start) to 320 s.
        (average: ((90 + 110 + 130 + 140 + 155) / 5).round(), max: 155),
      );
      expect(exerciseHeartRate(samples, const []), isNull);
    });

    test('compact forms round trip', () {
      expect(encodeHistogram({120: 9, 100: 10}), '100:10,120:9');
      expect(decodeHistogram('100:10,120:9,x'), {100: 10, 120: 9});
      expect(encodeCurve([107, null, 150]), '107,,150');
      expect(decodeCurve('107,,150'), [107, null, 150]);
      expect(decodeCurve(''), isEmpty);
    });

    test('violin: average distribution, shape, quartiles', () {
      final a = normalizeHistogram({100: 1, 120: 3});
      expect(a, {100: 0.25, 120: 0.75});
      // Each training counts the same, however long it was.
      expect(
        averageDistribution([
          {100: 10},
          {120: 1000},
        ]),
        {100: 0.5, 120: 0.5},
      );
      expect(averageDistribution(const []), isEmpty);

      final shape = violinShape(a, from: 90, to: 130);
      expect(shape.first.bpm, 90);
      expect(shape.last.bpm, 130);
      final widest = shape.reduce((x, y) => x.density > y.density ? x : y);
      expect(widest.bpm, 120);
      expect(widest.density, 1);

      expect(quartilesOf({100: 0.25, 110: 0.25, 120: 0.25, 130: 0.25}), (
        q1: 100,
        median: 110,
        q3: 120,
      ));
      expect(quartilesOf(const {}), isNull);
    });
  });
}
