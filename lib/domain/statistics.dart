/// Statistics (SPEC §6.5, §7.3–7.6): pure functions on loaded data. The
/// display period only cuts what is shown; calculations use all history.
library;

import 'calendar.dart';
import 'heart_rate_ranges.dart';
import 'metrics.dart';
import 'models/models.dart';
import 'period.dart';
import 'records.dart';

/// A finished training with its exercises and sets.
final class Training {
  const Training({required this.session, required this.exercises});

  final Session session;
  final List<SessionExerciseDetail> exercises;

  /// Local day of the start (SPEC §4).
  LocalDate get day => LocalDate.fromDateTime(session.startedAt);
}

/// Everything the statistics need.
final class StatsData {
  const StatsData({
    required this.trainings,
    required this.bodyWeights,
    required this.exercises,
    this.heartRates = const {},
  });

  /// Kept heart rate per session id (1.5.1).
  final Map<int, SessionHeartRate> heartRates;

  /// Finished trainings, oldest first.
  final List<Training> trainings;

  /// Oldest first.
  final List<BodyWeightEntry> bodyWeights;
  final List<Exercise> exercises;

  bool get hasBodyWeights => bodyWeights.isNotEmpty;

  static const empty = StatsData(trainings: [], bodyWeights: [], exercises: []);
}

// ---------------------------------------------------------------------------
// §7.3 effective load, §7.4 performance

/// Body weight of the entry closest to [day], before or after; on a tie the
/// earlier one. `null` without entries. [sortedAsc] must be sorted by date.
double? nearestBodyWeight(List<BodyWeightEntry> sortedAsc, LocalDate day) {
  if (sortedAsc.isEmpty) return null;
  var lo = 0;
  var hi = sortedAsc.length;
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (sortedAsc[mid].date.isBefore(day)) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  // lo = first entry on or after day.
  if (lo == sortedAsc.length) return sortedAsc.last.weightKg;
  if (lo == 0) return sortedAsc.first.weightKg;
  final after = sortedAsc[lo];
  final before = sortedAsc[lo - 1];
  final dAfter = after.date.differenceInDays(day);
  final dBefore = day.differenceInDays(before.date);
  return dBefore <= dAfter ? before.weightKg : after.weightKg;
}

/// Effective load of a bodyweight set: body weight + added weight (§7.3).
double? effectiveLoad(double? bodyWeight, SetEntry set) =>
    bodyWeight == null ? null : bodyWeight + (set.weightKg ?? 0);

/// Performance P of an exercise in one training (§7.4). For bodyweight
/// exercises [useBodyWeight] must be the same for the whole history: true
/// as soon as any body weight entry exists.
double? performance(
  ExerciseType type,
  Iterable<SetEntry> sets, {
  required bool useBodyWeight,
  double? bodyWeight,
}) {
  double? best;
  void take(double? v) {
    if (v != null && (best == null || v > best!)) best = v;
  }

  for (final s in workingSets(sets)) {
    switch (type) {
      case ExerciseType.weightReps:
        take(estimatedOneRepMax(s.weightKg ?? 0, s.reps ?? 0));
      case ExerciseType.bodyweight:
        if (useBodyWeight) {
          final load = effectiveLoad(bodyWeight, s);
          take(load == null ? null : estimatedOneRepMax(load, s.reps ?? 0));
        } else {
          take(s.reps?.toDouble());
        }
      case ExerciseType.timed:
        take(s.durationSec?.toDouble());
    }
  }
  return best;
}

// ---------------------------------------------------------------------------
// Exercise metrics (tab "Übung")

enum ExerciseMetric {
  estimatedOneRepMax,
  maxWeight,
  volume,
  maxReps,
  totalReps,
  maxAddedWeight,
  effectiveOneRepMax,
  maxDuration,
  totalDuration,
}

/// Metric chips per type; the first is the default (SPEC §6.5).
List<ExerciseMetric> metricsFor(
  ExerciseType type, {
  required bool hasBodyWeights,
}) => switch (type) {
  ExerciseType.weightReps => const [
    ExerciseMetric.estimatedOneRepMax,
    ExerciseMetric.maxWeight,
    ExerciseMetric.volume,
  ],
  ExerciseType.bodyweight => [
    ExerciseMetric.maxReps,
    ExerciseMetric.totalReps,
    ExerciseMetric.maxAddedWeight,
    if (hasBodyWeights) ExerciseMetric.effectiveOneRepMax,
  ],
  ExerciseType.timed => const [
    ExerciseMetric.maxDuration,
    ExerciseMetric.totalDuration,
  ],
};

double? metricValue(
  ExerciseMetric metric,
  List<SetEntry> sets, {
  double? bodyWeight,
}) {
  final working = workingSets(sets).toList();
  if (working.isEmpty) return null;
  double? max(Iterable<double?> values) {
    double? best;
    for (final v in values) {
      if (v != null && (best == null || v > best)) best = v;
    }
    return best;
  }

  double sum(Iterable<num?> values) => values.fold(0.0, (a, v) => a + (v ?? 0));

  return switch (metric) {
    ExerciseMetric.estimatedOneRepMax => max(
      working.map((s) => estimatedOneRepMax(s.weightKg ?? 0, s.reps ?? 0)),
    ),
    ExerciseMetric.maxWeight => max(working.map((s) => s.weightKg)),
    ExerciseMetric.volume => sum(
      working.map((s) => (s.weightKg ?? 0) * (s.reps ?? 0)),
    ),
    ExerciseMetric.maxReps => max(working.map((s) => s.reps?.toDouble())),
    ExerciseMetric.totalReps => sum(working.map((s) => s.reps)),
    ExerciseMetric.maxAddedWeight => max(working.map((s) => s.weightKg ?? 0)),
    ExerciseMetric.effectiveOneRepMax => max(
      working.map((s) {
        final load = effectiveLoad(bodyWeight, s);
        return load == null ? null : estimatedOneRepMax(load, s.reps ?? 0);
      }),
    ),
    ExerciseMetric.maxDuration => max(
      working.map((s) => s.durationSec?.toDouble()),
    ),
    ExerciseMetric.totalDuration => sum(working.map((s) => s.durationSec)),
  };
}

/// One point per training of an exercise.
final class SeriesPoint {
  const SeriesPoint({
    required this.training,
    required this.value,
    required this.sets,
    required this.isRecord,
  });

  final Training training;
  final double value;
  final List<SetEntry> sets;

  /// Strictly greater than every earlier point (never the first one).
  final bool isRecord;

  LocalDate get day => training.day;
}

List<SeriesPoint> exerciseSeries(
  StatsData data,
  int exerciseId,
  ExerciseMetric metric,
) {
  final result = <SeriesPoint>[];
  double? best;
  for (final t in data.trainings) {
    for (final d in t.exercises) {
      if (d.exercise.id != exerciseId || workingSets(d.sets).isEmpty) {
        continue;
      }
      final value = metricValue(
        metric,
        d.sets,
        bodyWeight: nearestBodyWeight(data.bodyWeights, t.day),
      );
      if (value == null) continue;
      result.add(
        SeriesPoint(
          training: t,
          value: value,
          sets: d.sets,
          isRecord: best != null && value > best,
        ),
      );
      if (best == null || value > best) best = value;
    }
  }
  return result;
}

/// Key figures of a series in the shown period.
final class SeriesSummary {
  const SeriesSummary({
    required this.best,
    required this.change,
    required this.changePercent,
    required this.count,
  });

  final double? best;

  /// Last minus first value in the period.
  final double? change;
  final double? changePercent;
  final int count;
}

SeriesSummary summarizeSeries(List<SeriesPoint> shown) {
  if (shown.isEmpty) {
    return const SeriesSummary(
      best: null,
      change: null,
      changePercent: null,
      count: 0,
    );
  }
  final first = shown.first.value;
  final last = shown.last.value;
  return SeriesSummary(
    best: shown.map((p) => p.value).reduce((a, b) => a > b ? a : b),
    change: shown.length < 2 ? null : last - first,
    changePercent: shown.length < 2 ? null : percentChange(last, first),
    count: shown.length,
  );
}

/// Exercises that have at least one working set, most recently trained
/// first.
List<Exercise> exercisesWithData(StatsData data) {
  final lastDay = <int, DateTime>{};
  final byId = <int, Exercise>{};
  for (final t in data.trainings) {
    for (final d in t.exercises) {
      if (workingSets(d.sets).isEmpty) continue;
      lastDay[d.exercise.id] = t.session.startedAt;
      byId[d.exercise.id] = d.exercise;
    }
  }
  final ids = lastDay.keys.toList()
    ..sort((a, b) => lastDay[b]!.compareTo(lastDay[a]!));
  return [for (final id in ids) byId[id]!];
}

// ---------------------------------------------------------------------------
// §7.5 strength index

/// How many weeks a value is carried forward without training.
const strengthIndexCarryWeeks = 8;

final class IndexPoint {
  const IndexPoint({
    required this.monday,
    required this.percent,
    required this.exerciseCount,
  });

  final LocalDate monday;
  final double percent;

  /// N: exercises included in this week.
  final int exerciseCount;
}

List<IndexPoint> strengthIndex(StatsData data, LocalDate today) {
  final useBw = data.hasBodyWeights;
  // Best P per included exercise and week (by Monday).
  final bestByWeek = <int, Map<LocalDate, double>>{};
  for (final t in data.trainings) {
    final bw = nearestBodyWeight(data.bodyWeights, t.day);
    for (final d in t.exercises) {
      if (!d.exercise.includeInStrengthIndex) continue;
      final p = performance(
        d.exercise.type,
        d.sets,
        useBodyWeight: useBw,
        bodyWeight: bw,
      );
      if (p == null || p <= 0) continue;
      final weeks = bestByWeek.putIfAbsent(d.exercise.id, () => {});
      final monday = mondayOf(t.day);
      final current = weeks[monday];
      if (current == null || p > current) weeks[monday] = p;
    }
  }
  if (bestByWeek.isEmpty) return const [];

  // Baseline B_e: P of the first training with e (first in time).
  final baseline = <int, double>{};
  for (final t in data.trainings) {
    for (final d in t.exercises) {
      if (baseline.containsKey(d.exercise.id) ||
          !bestByWeek.containsKey(d.exercise.id)) {
        continue;
      }
      final p = performance(
        d.exercise.type,
        d.sets,
        useBodyWeight: useBw,
        bodyWeight: nearestBodyWeight(data.bodyWeights, t.day),
      );
      if (p != null && p > 0) baseline[d.exercise.id] = p;
    }
  }

  final firstMonday = bestByWeek.values
      .expand((w) => w.keys)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final lastMonday = mondayOf(today);
  final lastValue = <int, (LocalDate, double)>{};
  final result = <IndexPoint>[];
  for (var w = firstMonday; !w.isAfter(lastMonday); w = w.addDays(7)) {
    final values = <double>[];
    for (final MapEntry(key: id, value: weeks) in bestByWeek.entries) {
      final p = weeks[w];
      if (p != null) {
        final i = p / baseline[id]!;
        lastValue[id] = (w, i);
        values.add(i);
      } else {
        final last = lastValue[id];
        if (last != null &&
            w.differenceInDays(last.$1) ~/ 7 <= strengthIndexCarryWeeks) {
          values.add(last.$2);
        }
      }
    }
    if (values.isEmpty) continue;
    result.add(
      IndexPoint(
        monday: w,
        percent: values.reduce((a, b) => a + b) / values.length * 100,
        exerciseCount: values.length,
      ),
    );
  }
  return result;
}

// ---------------------------------------------------------------------------
// §7.6 training volume and other overall charts

/// The volume of one training (1.3.1).
final class TrainingVolume {
  const TrainingVolume(this.day, this.value, {this.planName});

  final LocalDate day;
  final double value;
  final String? planName;
}

/// Volume of every training, oldest first – one bar each, side by side
/// without a time axis (1.3.1, replaces the weekly volume: weeks mix one
/// and three trainings). Trainings without volume (only bodyweight or timed
/// exercises) are left out.
List<TrainingVolume> trainingVolumes(StatsData data) => [
  for (final t in data.trainings)
    if (sessionVolume(t.exercises) case final v when v > 0)
      TrainingVolume(t.day, v, planName: t.session.planNameSnapshot),
];

/// Sets per local day for the last [weeks] weeks: `[week][weekday]` with
/// weekday 0 = Monday, oldest week first, the current week last.
List<List<int>> trainingHeatmap(
  StatsData data,
  LocalDate today, {
  int weeks = 26,
}) {
  final firstMonday = mondayOf(today).addDays(-7 * (weeks - 1));
  final grid = List.generate(weeks, (_) => List.filled(7, 0));
  for (final t in data.trainings) {
    final day = t.day;
    if (day.isBefore(firstMonday) || day.isAfter(today)) continue;
    final week = mondayOf(day).differenceInDays(firstMonday) ~/ 7;
    grid[week][day.weekday - 1] += t.exercises.fold(
      0,
      (n, d) => n + workingSets(d.sets).length,
    );
  }
  return grid;
}

/// Average trainings per week in the shown period (from its start or the
/// first training, whichever is later, to the current week).
double trainingsPerWeek(StatsData data, StatsPeriod period, LocalDate today) {
  if (data.trainings.isEmpty) return 0;
  final periodStart = period.startFor(today);
  final first = data.trainings.first.day;
  final start = periodStart == null || first.isAfter(periodStart)
      ? first
      : periodStart;
  final weeks = weeksBetween(start, today) + 1;
  final count = data.trainings
      .where((t) => !t.day.isBefore(start) && !t.day.isAfter(today))
      .length;
  return count / weeks;
}

/// Consecutive weeks with training up to now. The current week counts
/// once it has a training, but an empty current week does not break it.
int currentStreak(StatsData data, LocalDate today) {
  final weeks = {for (final t in data.trainings) mondayOf(t.day)};
  var w = mondayOf(today);
  if (!weeks.contains(w)) w = w.addDays(-7);
  var streak = 0;
  while (weeks.contains(w)) {
    streak++;
    w = w.addDays(-7);
  }
  return streak;
}

/// Longest run of consecutive weeks (Mo–So) with at least one training,
/// at any time; 0 without trainings.
int longestStreak(StatsData data) {
  final weeks = {for (final t in data.trainings) mondayOf(t.day)}.toList()
    ..sort();
  var best = 0;
  var run = 0;
  LocalDate? previous;
  for (final w in weeks) {
    run = previous != null && previous.addDays(7) == w ? run + 1 : 1;
    if (run > best) best = run;
    previous = w;
  }
  return best;
}

/// Working sets per category in the shown period.
Map<ExerciseCategory?, int> setsPerCategory(
  StatsData data,
  StatsPeriod period,
  LocalDate today,
) {
  final result = <ExerciseCategory?, int>{};
  for (final t in data.trainings) {
    if (!period.contains(t.day, today)) continue;
    for (final d in t.exercises) {
      final n = workingSets(d.sets).length;
      if (n == 0) continue;
      result[d.exercise.category] = (result[d.exercise.category] ?? 0) + n;
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Records tab

final class BestValue {
  const BestValue({required this.kind, required this.value, required this.day});

  final RecordKind kind;
  final double value;
  final LocalDate day;
}

/// Best value per record kind for every exercise with data (§7.7), sorted
/// by exercise name.
List<(Exercise, List<BestValue>)> recordsOverview(
  StatsData data,
  int Function(String, String) compareNames,
) {
  final sets = <int, List<SetEntry>>{};
  final days = <int, LocalDate>{};
  final exercises = <int, Exercise>{};
  for (final t in data.trainings) {
    for (final d in t.exercises) {
      for (final s in workingSets(d.sets)) {
        sets.putIfAbsent(d.exercise.id, () => []).add(s);
        days[s.id] = t.day;
        exercises[d.exercise.id] = d.exercise;
      }
    }
  }
  final result = [
    for (final MapEntry(key: id, value: list) in sets.entries)
      (
        exercises[id]!,
        [
          for (final MapEntry(key: kind, value: best) in bestValues(
            exercises[id]!.type,
            list,
          ).entries)
            BestValue(kind: kind, value: best.value, day: days[best.set.id]!),
        ],
      ),
  ];
  result.sort((a, b) => compareNames(a.$1.name, b.$1.name));
  return result;
}

// ---------------------------------------------------------------------------
// Heart rate (1.5.1)

/// Average and maximum heart rate of one training or exercise.
typedef HeartRateTrendPoint = ({LocalDate day, int average, int max});

/// Average and maximum heart rate of each training with a monitor, oldest
/// first.
List<HeartRateTrendPoint> trainingHeartRates(StatsData data) => [
  for (final t in data.trainings)
    if (data.heartRates[t.session.id] case final h?)
      (day: t.day, average: h.avgBpm, max: h.maxBpm),
];

/// Average and peak heart rate of one exercise in each training, oldest
/// first.
List<HeartRateTrendPoint> exerciseHeartRates(StatsData data, int exerciseId) =>
    [
      for (final t in data.trainings)
        for (final d in t.exercises)
          if (d.exercise.id == exerciseId)
            if ((d.sessionExercise.hrAvg, d.sessionExercise.hrMax) case (
              final avg?,
              final max?,
            ))
              (day: t.day, average: avg, max: max),
    ];

// ---------------------------------------------------------------------------
// Heart rate evaluations (1.6.0)

/// Estimated kilocalories of a training (Keytel), with the body weight
/// closest to its day; null if weight, birth year or sex is missing.
int? trainingCalories(
  SessionHeartRate h,
  DateTime startedAt,
  List<BodyWeightEntry> weightsAscending,
  AppSettings settings,
) => caloriesKeytel(
  averageBpm: h.avgBpm,
  seconds: h.seconds,
  weightKg: nearestBodyWeight(
    weightsAscending,
    LocalDate.fromDateTime(startedAt),
  ),
  age: settings.birthYear == null
      ? null
      : ageAt(settings.birthYear!, startedAt),
  sex: settings.sex,
);

/// One value per training.
typedef DayValue = ({LocalDate day, double value});

/// Heart rate recovery of each training that has one, oldest first.
List<DayValue> trainingRecoveries(StatsData data) => [
  for (final t in data.trainings)
    if (data.heartRates[t.session.id]?.recoveryBpm case final r?)
      (day: t.day, value: r.toDouble()),
];

/// One value per ISO week (Monday).
typedef WeekSum = ({LocalDate monday, double value});

/// Sums per week from the first week with heart rate to the current one,
/// weeks without training included as 0.
List<WeekSum> _weekly(
  StatsData data,
  LocalDate today,
  double? Function(Training t, SessionHeartRate h) valueOf,
) {
  final byWeek = <LocalDate, double>{};
  LocalDate? first;
  for (final t in data.trainings) {
    final h = data.heartRates[t.session.id];
    if (h == null) continue;
    final v = valueOf(t, h);
    if (v == null) continue;
    final monday = mondayOf(t.day);
    first ??= monday;
    byWeek[monday] = (byWeek[monday] ?? 0) + v;
  }
  if (first == null) return const [];
  return [
    for (var w = first; !w.isAfter(mondayOf(today)); w = w.addDays(7))
      (monday: w, value: byWeek[w] ?? 0),
  ];
}

/// Training load per week: Edwards' TRIMP from the minutes in the ranges.
List<WeekSum> weeklyLoad(StatsData data, LocalDate today, int hrMax) =>
    _weekly(data, today, (_, h) => edwardsTrimp(h.distribution, hrMax));

/// Estimated kilocalories per week.
List<WeekSum> weeklyCalories(
  StatsData data,
  LocalDate today,
  AppSettings settings,
) => _weekly(
  data,
  today,
  (t, h) => trainingCalories(
    h,
    t.session.startedAt,
    data.bodyWeights,
    settings,
  )?.toDouble(),
);
