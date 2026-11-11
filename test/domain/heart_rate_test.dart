import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/heart_rate.dart';
import 'package:gymlog/domain/models/models.dart';

/// 1.5.0: Bluetooth heart rate measurement and key figures.
void main() {
  group('parseHeartRateMeasurement (0x2A37)', () {
    test('8 and 16 bit values', () {
      expect(parseHeartRateMeasurement([0x00, 72]), 72);
      expect(parseHeartRateMeasurement([0x01, 0x2C, 0x00]), 44);
      expect(parseHeartRateMeasurement([0x01, 0xC8, 0x00, 0x10, 0x03]), 200);
      // RR intervals after the value do not matter.
      expect(parseHeartRateMeasurement([0x10, 130, 0x20, 0x03]), 130);
    });

    test('skin contact', () {
      // Contact supported (bit 2) and detected (bit 1).
      expect(parseHeartRateMeasurement([0x06, 95]), 95);
      // Supported but not detected: no value.
      expect(parseHeartRateMeasurement([0x04, 95]), isNull);
      // Not supported: the value counts.
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
  HeartRateSample at(int seconds, int bpm) => HeartRateSample(
    id: seconds,
    sessionId: 1,
    recordedAt: start.add(Duration(seconds: seconds)),
    bpm: bpm,
  );

  test('stats', () {
    expect(heartRateStats(const []), isNull);
    final s = heartRateStats([at(0, 90), at(5, 120), at(10, 151)])!;
    expect((s.average, s.max, s.min, s.count), (120, 151, 90, 3));
  });

  test('curve: minutes since start, averaged down to maxPoints', () {
    expect(heartRateCurve(const [], start), isEmpty);
    final few = heartRateCurve([at(60, 100), at(0, 80)], start);
    expect(few.map((p) => (p.minutes, p.bpm)), [(0.0, 80.0), (1.0, 100.0)]);

    // 1 hour every 5 s = 720 samples → at most 150 points.
    final many = [for (var i = 0; i < 720; i++) at(i * 5, 100 + i % 10)];
    final curve = heartRateCurve(many, start);
    expect(curve.length, lessThanOrEqualTo(150));
    expect(curve.first.minutes, lessThan(1));
    expect(curve.last.minutes, greaterThan(58));
    expect(
      curve.every((p) => p.bpm >= 100 && p.bpm <= 109),
      isTrue,
      reason: 'averages stay in the range of the values',
    );
  });

  test('shouldStoreSample: fresh reading, at most every 5 s', () {
    final now = start;
    expect(
      shouldStoreSample(now: now, lastReadingAt: now, lastStoredAt: null),
      isTrue,
    );
    expect(
      shouldStoreSample(
        now: now,
        lastReadingAt: now,
        lastStoredAt: now.subtract(const Duration(seconds: 4)),
      ),
      isFalse,
    );
    expect(
      shouldStoreSample(
        now: now,
        lastReadingAt: now,
        lastStoredAt: now.subtract(const Duration(seconds: 5)),
      ),
      isTrue,
    );
    expect(
      shouldStoreSample(
        now: now,
        lastReadingAt: now.subtract(const Duration(seconds: 6)),
        lastStoredAt: null,
      ),
      isFalse,
      reason: 'an old reading is not stored again',
    );
    expect(
      shouldStoreSample(now: now, lastReadingAt: null, lastStoredAt: null),
      isFalse,
    );
  });
}
