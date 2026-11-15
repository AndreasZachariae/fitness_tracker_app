import 'models/models.dart';
import 'period.dart';

/// A body weight entry with its 7-day moving average (SPEC §7.8).
typedef SmoothedWeight = ({BodyWeightEntry entry, double average});

/// For every entry with date d: mean of all entries in [d − 6 days, d].
/// [entries] may be in any order; the result is oldest first.
List<SmoothedWeight> movingAverage7(List<BodyWeightEntry> entries) {
  final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
  final result = <SmoothedWeight>[];
  var windowStart = 0;
  var sum = 0.0;
  for (var i = 0; i < sorted.length; i++) {
    final d = sorted[i].date;
    sum += sorted[i].weightKg;
    while (sorted[windowStart].date.isBefore(d.addDays(-6))) {
      sum -= sorted[windowStart].weightKg;
      windowStart++;
    }
    result.add((entry: sorted[i], average: sum / (i - windowStart + 1)));
  }
  return result;
}

/// Key figures of the body weight screen (SPEC §6.6).
final class BodyWeightStats {
  const BodyWeightStats({
    required this.current,
    required this.change30Days,
    required this.min,
    required this.max,
  });

  /// 7-day average at the latest entry.
  final double? current;

  /// Current 7-day average minus the one of the latest entry at least 30
  /// days earlier; `null` without such an entry.
  final double? change30Days;

  /// Lowest and highest entry within the period.
  final double? min;
  final double? max;
}

BodyWeightStats bodyWeightStats(
  List<SmoothedWeight> smoothed,
  StatsPeriod period,
  LocalDate today,
) {
  if (smoothed.isEmpty) {
    return const BodyWeightStats(
      current: null,
      change30Days: null,
      min: null,
      max: null,
    );
  }
  final latest = smoothed.last;
  final cutoff = latest.entry.date.addDays(-30);
  SmoothedWeight? before;
  for (final s in smoothed) {
    if (s.entry.date.isAfter(cutoff)) break;
    before = s;
  }
  final inPeriod = [
    for (final s in smoothed)
      if (period.contains(s.entry.date, today)) s.entry.weightKg,
  ];
  return BodyWeightStats(
    current: latest.average,
    change30Days: before == null ? null : latest.average - before.average,
    min: inPeriod.isEmpty ? null : inPeriod.reduce((a, b) => a < b ? a : b),
    max: inPeriod.isEmpty ? null : inPeriod.reduce((a, b) => a > b ? a : b),
  );
}

// More body values (1.7.0).

/// What the body chart shows; weight always, the others when measured.
enum BodyMetric { weight, fat, muscle, water, bone }

double? bodyMetricValue(BodyMetric metric, BodyWeightEntry e) =>
    switch (metric) {
      BodyMetric.weight => e.weightKg,
      BodyMetric.fat => e.fatPct,
      BodyMetric.muscle => e.musclePct,
      BodyMetric.water => e.waterPct,
      BodyMetric.bone => e.boneKg,
    };

/// Metrics with at least one value, in [BodyMetric] order (weight always).
List<BodyMetric> bodyMetricsWithData(List<BodyWeightEntry> entries) => [
  for (final m in BodyMetric.values)
    if (m == BodyMetric.weight ||
        entries.any((e) => bodyMetricValue(m, e) != null))
      m,
];

/// One point of the body chart; [average] only for the weight (7 days).
typedef BodyPoint = ({LocalDate date, double value, double? average});

/// The entries with a value of [metric], oldest first.
List<BodyPoint> bodyMetricSeries(
  List<BodyWeightEntry> entries,
  BodyMetric metric,
) {
  if (metric == BodyMetric.weight) {
    return [
      for (final s in movingAverage7(entries))
        (date: s.entry.date, value: s.entry.weightKg, average: s.average),
    ];
  }
  final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
  return [
    for (final e in sorted)
      if (bodyMetricValue(metric, e) case final v?)
        (date: e.date, value: v, average: null),
  ];
}

/// Key figures of [metric]: the weight as in SPEC §6.6 (7-day average);
/// the other values from the measurements themselves.
BodyWeightStats bodyMetricStats(
  List<BodyWeightEntry> entries,
  BodyMetric metric,
  StatsPeriod period,
  LocalDate today,
) {
  final points = bodyMetricSeries(entries, metric);
  if (points.isEmpty) {
    return const BodyWeightStats(
      current: null,
      change30Days: null,
      min: null,
      max: null,
    );
  }
  double valueOf(BodyPoint p) => p.average ?? p.value;
  final latest = points.last;
  final cutoff = latest.date.addDays(-30);
  BodyPoint? before;
  for (final p in points) {
    if (p.date.isAfter(cutoff)) break;
    before = p;
  }
  final inPeriod = [
    for (final p in points)
      if (period.contains(p.date, today)) p.value,
  ];
  return BodyWeightStats(
    current: valueOf(latest),
    change30Days: before == null ? null : valueOf(latest) - valueOf(before),
    min: inPeriod.isEmpty ? null : inPeriod.reduce((a, b) => a < b ? a : b),
    max: inPeriod.isEmpty ? null : inPeriod.reduce((a, b) => a > b ? a : b),
  );
}
