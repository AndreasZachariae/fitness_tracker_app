/// Heart rate from a Bluetooth monitor (1.5.0): decoding the standard
/// measurement and key figures of a training. Pure Dart.
library;

import 'models/models.dart';

/// Lowest and highest value GymLog accepts (also the database check).
const minBpm = 20;
const maxBpm = 255;

/// One value of the Bluetooth "Heart Rate Measurement" characteristic
/// (0x2A37): flags, then the value as 8 or 16 bit. Null when the monitor
/// reports no skin contact or the value is implausible.
int? parseHeartRateMeasurement(List<int> bytes) {
  if (bytes.length < 2) return null;
  final flags = bytes[0];
  final wide = flags & 0x01 != 0;
  final contactSupported = flags & 0x04 != 0;
  final contact = flags & 0x02 != 0;
  if (contactSupported && !contact) return null;
  final int bpm;
  if (wide) {
    if (bytes.length < 3) return null;
    bpm = bytes[1] | (bytes[2] << 8);
  } else {
    bpm = bytes[1];
  }
  return bpm < minBpm || bpm > maxBpm ? null : bpm;
}

/// Average and maximum of a training.
typedef HeartRateStats = ({int average, int max, int min, int count});

HeartRateStats? heartRateStats(Iterable<HeartRateSample> samples) {
  var sum = 0;
  var count = 0;
  var max = 0;
  var min = maxBpm;
  for (final s in samples) {
    sum += s.bpm;
    count++;
    if (s.bpm > max) max = s.bpm;
    if (s.bpm < min) min = s.bpm;
  }
  if (count == 0) return null;
  return (average: (sum / count).round(), max: max, min: min, count: count);
}

/// A point of the curve: minutes since [start] and beats per minute.
typedef HeartRatePoint = ({double minutes, double bpm});

/// The curve for a chart: at most [maxPoints] points, each the average of
/// the samples in its time slice, in time order.
List<HeartRatePoint> heartRateCurve(
  List<HeartRateSample> samples,
  DateTime start, {
  int maxPoints = 150,
}) {
  if (samples.isEmpty) return const [];
  final sorted = [...samples]
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final perPoint = (sorted.length / maxPoints).ceil().clamp(1, sorted.length);
  final points = <HeartRatePoint>[];
  for (var i = 0; i < sorted.length; i += perPoint) {
    final slice = sorted.sublist(i, (i + perPoint).clamp(0, sorted.length));
    final bpm = slice.fold<int>(0, (n, s) => n + s.bpm) / slice.length;
    final middle = slice[slice.length ~/ 2].recordedAt;
    points.add((
      minutes: middle.difference(start).inMilliseconds / 60000,
      bpm: bpm,
    ));
  }
  return points;
}

/// Whether the recorder stores a new sample: the last reading is fresh and
/// the last sample is at least [every] old.
bool shouldStoreSample({
  required DateTime now,
  required DateTime? lastReadingAt,
  required DateTime? lastStoredAt,
  Duration every = const Duration(seconds: 5),
}) =>
    lastReadingAt != null &&
    now.difference(lastReadingAt) <= every &&
    (lastStoredAt == null || now.difference(lastStoredAt) >= every);
