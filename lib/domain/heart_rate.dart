/// Heart rate from a Bluetooth monitor (1.5.0): decoding the standard
/// measurement and key figures of a training. Pure Dart.
library;

import 'dart:math' as math;

import 'models/models.dart';

/// Lowest and highest value GymLog accepts (also the database check).
const minBpm = 20;
const maxBpm = 255;

/// One value of a monitor: beats per minute and whether the message also
/// carried RR intervals (time between beats, needed for HRV; 1.5.1).
typedef HeartRateReading = ({int bpm, bool hasRr});

/// One message of the Bluetooth "Heart Rate Measurement" characteristic
/// (0x2A37): flags, the value as 8 or 16 bit, optionally energy and RR
/// intervals. Null when the monitor reports no skin contact or the value is
/// implausible.
HeartRateReading? parseHeartRateReading(List<int> bytes) {
  if (bytes.length < 2) return null;
  final flags = bytes[0];
  final wide = flags & 0x01 != 0;
  final contactSupported = flags & 0x04 != 0;
  final contact = flags & 0x02 != 0;
  final energy = flags & 0x08 != 0;
  final rr = flags & 0x10 != 0;
  if (contactSupported && !contact) return null;
  final int bpm;
  if (wide) {
    if (bytes.length < 3) return null;
    bpm = bytes[1] | (bytes[2] << 8);
  } else {
    bpm = bytes[1];
  }
  if (bpm < minBpm || bpm > maxBpm) return null;
  final rrStart = (wide ? 3 : 2) + (energy ? 2 : 0);
  return (bpm: bpm, hasRr: rr && bytes.length >= rrStart + 2);
}

/// Only the beats per minute of [parseHeartRateReading].
int? parseHeartRateMeasurement(List<int> bytes) =>
    parseHeartRateReading(bytes)?.bpm;

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

// ---------------------------------------------------------------------------
// Summaries (1.5.1): only these are kept after a training, not the series.

/// A gap longer than this counts as a gap (monitor lost), not as time at the
/// last value.
const _maxGap = Duration(seconds: 5);

/// Seconds each sample stands for: the time to the next one, at most
/// [_maxGap]; the last one 1 s. Samples must be sorted.
List<double> _weights(List<HeartRateSample> sorted) => [
  for (var i = 0; i < sorted.length; i++)
    i + 1 < sorted.length
        ? (sorted[i + 1].recordedAt
                      .difference(sorted[i].recordedAt)
                      .inMilliseconds /
                  1000)
              .clamp(0, _maxGap.inSeconds)
              .toDouble()
        : 1.0,
];

/// What is kept of a training's heart rate.
final class HeartRateSummary {
  const HeartRateSummary({
    required this.average,
    required this.max,
    required this.min,
    required this.seconds,
    required this.histogram,
    required this.curve,
  });

  /// Time-weighted average, beats per minute.
  final int average;
  final int max;
  final int min;

  /// Seconds with heart rate.
  final int seconds;

  /// Seconds per beats-per-minute value: the distribution (violin plot).
  final Map<int, int> histogram;

  /// Average per minute since the start of the training; null = no value in
  /// that minute.
  final List<int?> curve;
}

HeartRateSummary? summarizeHeartRate(
  List<HeartRateSample> samples,
  DateTime start,
) {
  if (samples.isEmpty) return null;
  final sorted = [...samples]
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final weights = _weights(sorted);
  var sum = 0.0;
  var total = 0.0;
  var max = 0;
  var min = maxBpm;
  final histogram = <int, double>{};
  final minuteSum = <int, double>{};
  final minuteCount = <int, int>{};
  for (var i = 0; i < sorted.length; i++) {
    final s = sorted[i];
    final w = weights[i];
    sum += s.bpm * w;
    total += w;
    if (s.bpm > max) max = s.bpm;
    if (s.bpm < min) min = s.bpm;
    histogram[s.bpm] = (histogram[s.bpm] ?? 0) + w;
    final minute = s.recordedAt.difference(start).inSeconds ~/ 60;
    if (minute >= 0) {
      minuteSum[minute] = (minuteSum[minute] ?? 0) + s.bpm;
      minuteCount[minute] = (minuteCount[minute] ?? 0) + 1;
    }
  }
  final lastMinute = minuteSum.keys.fold<int>(-1, (a, b) => b > a ? b : a);
  return HeartRateSummary(
    average: total == 0 ? sorted.first.bpm : (sum / total).round(),
    max: max,
    min: min,
    seconds: total.round(),
    histogram: {
      for (final MapEntry(:key, :value) in histogram.entries)
        if (value.round() > 0) key: value.round(),
    },
    curve: [
      for (var m = 0; m <= lastMinute; m++)
        minuteCount[m] == null
            ? null
            : (minuteSum[m]! / minuteCount[m]!).round(),
    ],
  );
}

/// The time of a set for its heart rate: a timed set from its duration, any
/// other the minute before saving – not before the previous set of the
/// exercise. The peak counts until [afterSet] later, because the heart rate
/// keeps rising for a moment after the set.
typedef SetWindow = ({DateTime start, DateTime end, DateTime completedAt});

const afterSet = Duration(seconds: 20);
const assumedSetDuration = Duration(seconds: 60);

SetWindow setWindow({
  required DateTime completedAt,
  DateTime? previousCompletedAt,
  int? durationSec,
}) {
  var start = completedAt.subtract(
    durationSec != null ? Duration(seconds: durationSec) : assumedSetDuration,
  );
  if (previousCompletedAt != null && start.isBefore(previousCompletedAt)) {
    start = previousCompletedAt;
  }
  return (
    start: start,
    end: completedAt.add(afterSet),
    completedAt: completedAt,
  );
}

/// Average during the set and peak until shortly after it.
typedef SetHeartRate = ({int average, int peak});

SetHeartRate? setHeartRate(List<HeartRateSample> samples, SetWindow w) {
  final inPeak = [
    for (final s in samples)
      if (!s.recordedAt.isBefore(w.start) && !s.recordedAt.isAfter(w.end)) s,
  ];
  if (inPeak.isEmpty) return null;
  final during = [
    for (final s in inPeak)
      if (!s.recordedAt.isAfter(w.completedAt)) s,
  ];
  final avgOf = during.isEmpty ? inPeak : during;
  return (
    average: (avgOf.fold<int>(0, (n, s) => n + s.bpm) / avgOf.length).round(),
    peak: inPeak.fold<int>(0, (m, s) => s.bpm > m ? s.bpm : m),
  );
}

/// Windows of the sets of one exercise, in order.
List<SetWindow> setWindows(List<SetEntry> sets) {
  final sorted = [...sets]
    ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
  return [
    for (var i = 0; i < sorted.length; i++)
      setWindow(
        completedAt: sorted[i].completedAt,
        previousCompletedAt: i == 0 ? null : sorted[i - 1].completedAt,
        durationSec: sorted[i].durationSec,
      ),
  ];
}

/// Average and maximum over all sets of an exercise (from the first set's
/// start to shortly after the last one).
typedef ExerciseHeartRate = ({int average, int max});

ExerciseHeartRate? exerciseHeartRate(
  List<HeartRateSample> samples,
  List<SetEntry> sets,
) {
  final windows = setWindows(sets);
  if (windows.isEmpty) return null;
  final from = windows.first.start;
  final to = windows.last.end;
  final inside = [
    for (final s in samples)
      if (!s.recordedAt.isBefore(from) && !s.recordedAt.isAfter(to)) s,
  ];
  if (inside.isEmpty) return null;
  return (
    average: (inside.fold<int>(0, (n, s) => n + s.bpm) / inside.length).round(),
    max: inside.fold<int>(0, (m, s) => s.bpm > m ? s.bpm : m),
  );
}

// Compact text forms for the database and the backup.

/// `"92:12,93:30"` – beats per minute and seconds.
String encodeHistogram(Map<int, int> histogram) {
  final keys = histogram.keys.toList()..sort();
  return [for (final k in keys) '$k:${histogram[k]}'].join(',');
}

Map<int, int> decodeHistogram(String text) {
  final result = <int, int>{};
  for (final part in text.split(',')) {
    final pair = part.split(':');
    if (pair.length != 2) continue;
    final bpm = int.tryParse(pair[0]);
    final seconds = int.tryParse(pair[1]);
    if (bpm != null && seconds != null) result[bpm] = seconds;
  }
  return result;
}

/// `"110,,124"` – one value per minute, empty = no value.
String encodeCurve(List<int?> curve) => curve.map((v) => v ?? '').join(',');

List<int?> decodeCurve(String text) => text.isEmpty
    ? const []
    : [for (final v in text.split(',')) int.tryParse(v)];

// Violin plot (1.5.1).

/// Shares per beats-per-minute value (sum 1).
Map<int, double> normalizeHistogram(Map<int, int> histogram) {
  final total = histogram.values.fold<int>(0, (a, b) => a + b);
  if (total == 0) return const {};
  return {
    for (final MapEntry(:key, :value) in histogram.entries) key: value / total,
  };
}

/// The average distribution of several trainings, each weighted the same.
Map<int, double> averageDistribution(Iterable<Map<int, int>> histograms) {
  final list = [
    for (final h in histograms)
      if (normalizeHistogram(h) case final n when n.isNotEmpty) n,
  ];
  if (list.isEmpty) return const {};
  final result = <int, double>{};
  for (final n in list) {
    for (final MapEntry(:key, :value) in n.entries) {
      result[key] = (result[key] ?? 0) + value / list.length;
    }
  }
  return result;
}

/// Smoothed density (Gaussian kernel) of a distribution from [from] to [to]
/// in steps of 1 bpm; the maximum is 1.
List<({int bpm, double density})> violinShape(
  Map<int, double> distribution, {
  required int from,
  required int to,
  double bandwidth = 3,
}) {
  if (distribution.isEmpty) return const [];
  final raw = <({int bpm, double density})>[];
  var peak = 0.0;
  for (var bpm = from; bpm <= to; bpm++) {
    var d = 0.0;
    for (final MapEntry(:key, :value) in distribution.entries) {
      final z = (bpm - key) / bandwidth;
      d += value * _exp(-0.5 * z * z);
    }
    if (d > peak) peak = d;
    raw.add((bpm: bpm, density: d));
  }
  return [
    for (final r in raw)
      (bpm: r.bpm, density: peak == 0 ? 0 : r.density / peak),
  ];
}

/// Quartiles and median of a distribution.
typedef Quartiles = ({int q1, int median, int q3});

Quartiles? quartilesOf(Map<int, double> distribution) {
  if (distribution.isEmpty) return null;
  final keys = distribution.keys.toList()..sort();
  final total = distribution.values.fold<double>(0, (a, b) => a + b);
  int at(double share) {
    var sum = 0.0;
    for (final k in keys) {
      sum += distribution[k]!;
      if (sum >= share * total - 1e-9) return k;
    }
    return keys.last;
  }

  return (q1: at(0.25), median: at(0.5), q3: at(0.75));
}

double _exp(double x) => math.exp(x);
