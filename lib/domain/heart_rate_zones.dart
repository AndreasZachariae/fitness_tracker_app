/// Heart rate zones and what follows from them (1.6.0, zones after the
/// lactate threshold since 1.6.1): time in zones, training load, calories,
/// heart rate recovery, warm-up targets. Pure Dart.
library;

import 'heart_rate.dart';
import 'models/models.dart';

/// Lower bounds of Garmin's zones 1–5 as share of the lactate threshold
/// heart rate ("%LSHF" on the watch, 1.6.1); zone 5 ends at [zoneTopShare].
const thresholdZoneShares = [0.57, 0.67, 0.79, 0.90, 1.01];
const zoneTopShare = 1.13;

/// One zone in beats per minute, both bounds included.
typedef HeartRateZone = ({int number, int from, int to});

List<HeartRateZone> heartRateZones(int threshold) => [
  for (var i = 0; i < 5; i++)
    (
      number: i + 1,
      from: (threshold * thresholdZoneShares[i]).round(),
      to: i == 4
          ? (threshold * zoneTopShare).round()
          : (threshold * thresholdZoneShares[i + 1]).round() - 1,
    ),
];

/// Zone 1–5 of [bpm]; 0 below zone 1, above zone 5 still 5.
int zoneOf(int bpm, int threshold) {
  var zone = 0;
  for (final z in heartRateZones(threshold)) {
    if (bpm >= z.from) zone = z.number;
  }
  return zone;
}

/// Seconds in zone 0 (below 1) to 5 from a distribution (seconds per bpm).
Map<int, int> secondsPerZone(Map<int, int> histogram, int threshold) {
  final result = {for (var z = 0; z <= 5; z++) z: 0};
  for (final MapEntry(key: bpm, value: seconds) in histogram.entries) {
    final z = zoneOf(bpm, threshold);
    result[z] = result[z]! + seconds;
  }
  return result;
}

/// Edwards' TRIMP: minutes in zone 1 × 1 + … + minutes in zone 5 × 5.
double edwardsTrimp(Map<int, int> histogram, int threshold) {
  var load = 0.0;
  for (final MapEntry(key: zone, value: seconds) in secondsPerZone(
    histogram,
    threshold,
  ).entries) {
    load += zone * seconds / 60;
  }
  return load;
}

/// "Pause nach Puls" ends below this by default: the top of zone 1.
int defaultPauseBpm(int threshold) => heartRateZones(threshold).first.to;

/// Suggested warning: 107 % of the threshold, about 95 % of the maximum.
const warnShare = 1.07;
int defaultWarnBpm(int threshold) => (threshold * warnShare).round();

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
/// peak of a hard set (zone 3 and up when the threshold is known). The peak
/// is searched until [recoveryPeakAfterSet] after the set, because a watch
/// at the wrist reacts late; a set whose next set starts within the minute
/// does not count. The average drop over the sets; null without one.
const recoveryPeakAfterSet = Duration(seconds: 45);

int? heartRateRecovery(
  List<HeartRateSample> samples,
  List<SetWindow> windows, {
  int? threshold,
}) {
  if (samples.isEmpty) return null;
  final sorted = [...samples]
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final hard = threshold == null ? null : heartRateZones(threshold)[2].from;
  final drops = <int>[];
  for (final w in windows) {
    final until = w.completedAt.add(recoveryPeakAfterSet);
    HeartRateSample? peak;
    for (final s in sorted) {
      if (s.recordedAt.isBefore(w.start) || s.recordedAt.isAfter(until)) {
        continue;
      }
      if (peak == null || s.bpm > peak.bpm) peak = s;
    }
    if (peak == null) continue;
    if (hard != null && peak.bpm < hard) continue;
    final target = peak.recordedAt.add(const Duration(seconds: 60));
    // The next set must not start before the minute is over.
    final interrupted = windows.any(
      (o) =>
          !identical(o, w) &&
          o.start.isAfter(peak!.recordedAt) &&
          o.start.isBefore(target),
    );
    if (interrupted) continue;
    HeartRateSample? later;
    var best = const Duration(seconds: 6);
    for (final s in sorted) {
      final d = s.recordedAt.difference(target).abs();
      if (d < best) {
        best = d;
        later = s;
      }
    }
    // Higher a minute later: the peak was not over yet (1.6.1).
    if (later != null && later.bpm <= peak.bpm) drops.add(peak.bpm - later.bpm);
  }
  if (drops.isEmpty) return null;
  return (drops.fold<int>(0, (a, b) => a + b) / drops.length).round();
}

/// The heart rate target of a warm-up / cardio exercise: a zone (time
/// inside counts) or a bpm value (time at or above counts).
bool inTarget(int bpm, {int? zone, int? targetBpm, int? threshold}) {
  if (zone != null && threshold != null) return zoneOf(bpm, threshold) == zone;
  if (targetBpm != null) return bpm >= targetBpm;
  return false;
}

/// Seconds in the target between [from] and [to] (each value counts until
/// the next, at most 5 s).
int secondsInTarget(
  List<HeartRateSample> samples, {
  required DateTime from,
  required DateTime to,
  int? zone,
  int? targetBpm,
  int? threshold,
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
      zone: zone,
      targetBpm: targetBpm,
      threshold: threshold,
    )) {
      seconds += w;
    }
  }
  return seconds.round();
}
