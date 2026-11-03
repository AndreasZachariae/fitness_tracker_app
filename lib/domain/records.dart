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

/// Which sets of ONE exercise set new records, given all its sets in
/// chronological order (SPEC §7.7): strictly greater than every earlier
/// working set, including earlier sets of the same session. Sets of the
/// very first session of the exercise never count as records.
Map<int, List<RecordKind>> detectRecords(
  ExerciseType type,
  List<HistorySet> chronological,
) {
  final working = [
    for (final h in chronological)
      if (!h.set.isWarmup) h,
  ];
  if (working.isEmpty) return const {};
  final firstSession = working.first.sessionId;
  final kinds = recordKindsFor(type);
  final best = <RecordKind, double>{};
  final result = <int, List<RecordKind>>{};
  for (final h in working) {
    final hit = <RecordKind>[];
    for (final kind in kinds) {
      final value = recordValue(kind, h.set);
      if (value == null) continue;
      final previous = best[kind];
      if (h.sessionId != firstSession && previous != null && value > previous) {
        hit.add(kind);
      }
      if (previous == null || value > previous) best[kind] = value;
    }
    if (hit.isNotEmpty) result[h.set.id] = hit;
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
