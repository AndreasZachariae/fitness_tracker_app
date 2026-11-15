import 'models/models.dart';

/// Estimated one-rep max (Epley, SPEC §7.3): `w` for one rep, otherwise
/// `w × (1 + r / 30)`. Undefined (`null`) for r ≤ 0 or w ≤ 0.
double? estimatedOneRepMax(double weightKg, int reps) {
  if (reps <= 0 || weightKg <= 0) return null;
  return reps == 1 ? weightKg : weightKg * (1 + reps / 30);
}

/// Kinds of records per exercise type (SPEC §7.7).
enum RecordKind { estimatedOneRepMax, weight, reps, addedWeight, duration }

List<RecordKind> recordKindsFor(ExerciseType type) => switch (type) {
  ExerciseType.weightReps => const [
    RecordKind.estimatedOneRepMax,
    RecordKind.weight,
  ],
  ExerciseType.bodyweight => const [RecordKind.reps, RecordKind.addedWeight],
  ExerciseType.timed => const [RecordKind.duration],
};

/// The value of [set] for a record kind, `null` if it has none.
double? recordValue(RecordKind kind, SetEntry set) => switch (kind) {
  RecordKind.estimatedOneRepMax => estimatedOneRepMax(
    set.weightKg ?? 0,
    set.reps ?? 0,
  ),
  RecordKind.weight => set.weightKg,
  RecordKind.reps => set.reps?.toDouble(),
  RecordKind.addedWeight => set.weightKg,
  RecordKind.duration => set.durationSec?.toDouble(),
};

/// A set of one exercise together with its session.
typedef HistorySet = ({SetEntry set, int sessionId});

// Exercise record (1.6.3): the whole exercise of a training, not one set.

/// What the exercise record measures: volume (kg × reps), total reps or
/// total time.
enum ExerciseTotalKind { volume, reps, duration }

ExerciseTotalKind exerciseTotalKind(ExerciseType type) => switch (type) {
  ExerciseType.weightReps => ExerciseTotalKind.volume,
  ExerciseType.bodyweight => ExerciseTotalKind.reps,
  ExerciseType.timed => ExerciseTotalKind.duration,
};

/// The total of [sets] (working sets only): Σ weight × reps, Σ reps or
/// Σ seconds.
double exerciseTotal(ExerciseType type, Iterable<SetEntry> sets) {
  var total = 0.0;
  for (final s in sets) {
    if (s.isWarmup) continue;
    total += switch (exerciseTotalKind(type)) {
      ExerciseTotalKind.volume => (s.weightKg ?? 0) * (s.reps ?? 0),
      ExerciseTotalKind.reps => (s.reps ?? 0).toDouble(),
      ExerciseTotalKind.duration => (s.durationSec ?? 0).toDouble(),
    };
  }
  return total;
}

/// An exercise in one training: its [total] and the [best] total of the
/// trainings before (null: no earlier training, so no record yet).
typedef ExerciseRecordStatus = ({double total, double? best});

extension ExerciseRecordStatusX on ExerciseRecordStatus {
  /// Strictly more than every earlier training.
  bool get isRecord => best != null && total > best!;

  /// How much is missing to the record (0 when reached).
  double get missing => best == null || total > best! ? 0 : best! - total;
}

/// Totals per training of ONE exercise from its sets in chronological
/// order, in the order of the trainings (working sets only).
List<({int sessionId, double total})> _totalsPerSession(
  ExerciseType type,
  List<HistorySet> chronological,
) {
  final order = <int>[];
  final sets = <int, List<SetEntry>>{};
  for (final h in chronological) {
    if (h.set.isWarmup) continue;
    if (!sets.containsKey(h.sessionId)) order.add(h.sessionId);
    sets.putIfAbsent(h.sessionId, () => []).add(h.set);
  }
  return [
    for (final id in order)
      (sessionId: id, total: exerciseTotal(type, sets[id]!)),
  ];
}

/// The record status of the exercise in training [sessionId]: compared with
/// the trainings before it. A training without sets yet (just started)
/// compares with all others.
ExerciseRecordStatus exerciseRecordStatus(
  ExerciseType type,
  List<HistorySet> chronological,
  int sessionId,
) {
  double? best;
  var total = 0.0;
  for (final t in _totalsPerSession(type, chronological)) {
    if (t.sessionId == sessionId) {
      total = t.total;
      break;
    }
    if (best == null || t.total > best) best = t.total;
  }
  return (total: total, best: best);
}

/// The trainings in which ONE exercise set a record: more than in every
/// training before. The first training never counts.
Set<int> exerciseRecordSessions(
  ExerciseType type,
  List<HistorySet> chronological,
) {
  final result = <int>{};
  double? best;
  for (final t in _totalsPerSession(type, chronological)) {
    if (best != null && t.total > best) result.add(t.sessionId);
    if (best == null || t.total > best) best = t.total;
  }
  return result;
}

/// The best value per record kind over [sets] (for the records overview).
Map<RecordKind, ({double value, SetEntry set})> bestValues(
  ExerciseType type,
  Iterable<SetEntry> sets,
) {
  final result = <RecordKind, ({double value, SetEntry set})>{};
  for (final set in sets) {
    if (set.isWarmup) continue;
    for (final kind in recordKindsFor(type)) {
      final value = recordValue(kind, set);
      if (value == null) continue;
      final current = result[kind];
      if (current == null || value > current.value) {
        result[kind] = (value: value, set: set);
      }
    }
  }
  return result;
}
