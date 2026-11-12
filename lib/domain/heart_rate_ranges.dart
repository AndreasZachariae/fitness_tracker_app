/// Garmin heart rate ranges and what follows from them (1.6.0): time in
/// ranges, training load, calories, heart rate recovery, cardio targets.
/// Pure Dart.
///
/// Deliberately "Bereich" (range), not "Zone": Garmin's default ranges are
/// shares of the maximum heart rate, while classic "zone 2 training" means
/// the intensity below the first lactate threshold, which differs from
/// person to person.
library;

import 'heart_rate.dart';
import 'models/models.dart';

/// Lower bounds of Garmin's default ranges 1–5 as share of the maximum.
const garminRangeShares = [0.5, 0.6, 0.7, 0.8, 0.9];

/// One range in beats per minute, both bounds included.
typedef HeartRateRange = ({int number, int from, int to});

List<HeartRateRange> garminRanges(int hrMax) => [
  for (var i = 0; i < 5; i++)
    (
      number: i + 1,
      from: (hrMax * garminRangeShares[i]).round(),
      to: i == 4 ? hrMax : (hrMax * garminRangeShares[i + 1]).round() - 1,
    ),
];

/// Range 1–5 of [bpm]; 0 below range 1, above the maximum still 5.
int rangeOf(int bpm, int hrMax) {
  var range = 0;
  for (final r in garminRanges(hrMax)) {
    if (bpm >= r.from) range = r.number;
  }
  return range;
}

/// Seconds in range 0 (below 1) to 5 from a distribution (seconds per bpm).
Map<int, int> secondsPerRange(Map<int, int> histogram, int hrMax) {
  final result = {for (var r = 0; r <= 5; r++) r: 0};
  for (final MapEntry(key: bpm, value: seconds) in histogram.entries) {
    final r = rangeOf(bpm, hrMax);
    result[r] = result[r]! + seconds;
  }
  return result;
}

/// Edwards' TRIMP: minutes in range 1 × 1 + … + minutes in range 5 × 5.
/// Needs only the maximum heart rate (no resting heart rate).
double edwardsTrimp(Map<int, int> histogram, int hrMax) {
  var load = 0.0;
  for (final MapEntry(key: range, value: seconds) in secondsPerRange(
    histogram,
    hrMax,
  ).entries) {
    load += range * seconds / 60;
  }
  return load;
}

/// Pause ends below this by default: the top of range 1 (60 %).
int defaultPauseBpm(int hrMax) => (hrMax * 0.6).round();

/// Suggested warning: 95 % of the maximum.
int defaultWarnBpm(int hrMax) => (hrMax * 0.95).round();

/// Age in the year of [date].
int ageAt(int birthYear, DateTime date) => date.toLocal().year - birthYear;

/// Kilocalories by Keytel et al. (2005) from the average heart rate, body
/// weight, age and sex; null if something is missing. An estimate for
/// moderate to high heart rates; for strength training only a rough guide.
int? caloriesKeytel({
  required int averageBpm,
  required int seconds,
  required double? weightKg,
  required int? age,
  required Sex? sex,
}) {
  if (weightKg == null || age == null || sex == null || seconds <= 0) {
    return null;
  }
  final perMinuteKj = switch (sex) {
    Sex.male =>
      -55.0969 + 0.6309 * averageBpm + 0.1988 * weightKg + 0.2017 * age,
    Sex.female =>
      -20.4022 + 0.4472 * averageBpm - 0.1263 * weightKg + 0.074 * age,
  };
  final kcal = perMinuteKj / 4.184 * seconds / 60;
  return kcal <= 0 ? 0 : kcal.round();
}

/// Heart rate recovery: how far the heart rate falls in the 60 s after the
/// peak of a hard set (peak at least 70 % of the maximum when it is known).
/// The average drop over the sets; null without a usable set.
int? heartRateRecovery(
  List<HeartRateSample> samples,
  List<SetWindow> windows, {
  int? hrMax,
}) {
  if (samples.isEmpty) return null;
  final sorted = [...samples]
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final drops = <int>[];
  for (final w in windows) {
    HeartRateSample? peak;
    for (final s in sorted) {
      if (s.recordedAt.isBefore(w.start) || s.recordedAt.isAfter(w.end)) {
        continue;
      }
      if (peak == null || s.bpm > peak.bpm) peak = s;
    }
    if (peak == null) continue;
    if (hrMax != null && peak.bpm < hrMax * 0.7) continue;
    final target = peak.recordedAt.add(const Duration(seconds: 60));
    HeartRateSample? later;
    var best = const Duration(seconds: 6);
    for (final s in sorted) {
      final d = s.recordedAt.difference(target).abs();
      if (d < best) {
        best = d;
        later = s;
      }
    }
    if (later != null) drops.add(peak.bpm - later.bpm);
  }
  if (drops.isEmpty) return null;
  return (drops.fold<int>(0, (a, b) => a + b) / drops.length).round();
}

/// The heart rate target of a cardio / warm-up exercise: a range (time
/// inside counts) or a bpm value (time at or above counts).
bool inTarget(int bpm, {int? range, int? targetBpm, int? hrMax}) {
  if (range != null && hrMax != null) return rangeOf(bpm, hrMax) == range;
  if (targetBpm != null) return bpm >= targetBpm;
  return false;
}

/// Seconds in the target between [from] and [to] (each value counts until
/// the next, at most 5 s).
int secondsInTarget(
  List<HeartRateSample> samples, {
  required DateTime from,
  required DateTime to,
  int? range,
  int? targetBpm,
  int? hrMax,
}) {
  final sorted = [
    for (final s in samples)
      if (!s.recordedAt.isBefore(from) && !s.recordedAt.isAfter(to)) s,
  ]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  var seconds = 0.0;
  for (var i = 0; i < sorted.length; i++) {
    final next = i + 1 < sorted.length ? sorted[i + 1].recordedAt : to;
    final w = (next.difference(sorted[i].recordedAt).inMilliseconds / 1000)
        .clamp(0, 5);
    if (inTarget(
      sorted[i].bpm,
      range: range,
      targetBpm: targetBpm,
      hrMax: hrMax,
    )) {
      seconds += w;
    }
  }
  return seconds.round();
}
