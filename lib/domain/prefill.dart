import 'models/models.dart';

/// Prefilled values for the next set of a session exercise (SPEC §7.1).
///
/// [currentSets]: sets of this exercise in the running session.
/// [lastSessionSets]: sets of the exercise in the last finished session.
/// Only working sets count. Fields that do not belong to [type] are `null`.
SetValues prefillSet({
  required ExerciseType type,
  required List<SetEntry> currentSets,
  required List<SetEntry> lastSessionSets,
  int? targetReps,
  int? targetDurationSec,
}) {
  final current = currentSets.where((s) => !s.isWarmup).toList();
  final last = lastSessionSets.where((s) => !s.isWarmup).toList();
  final n = current.length + 1;

  // 1. Set n−1 of this session; 2. set n (or the last set) of the last session.
  final SetEntry? source = current.isNotEmpty
      ? current.last
      : last.isEmpty
      ? null
      : (n <= last.length ? last[n - 1] : last.last);

  // 3. Targets; weight empty (weight_reps) or 0 (bodyweight).
  return switch (type) {
    ExerciseType.weightReps => SetValues(
      weightKg: source?.weightKg,
      reps: source?.reps ?? targetReps,
    ),
    ExerciseType.bodyweight => SetValues(
      weightKg: source?.weightKg ?? 0,
      reps: source?.reps ?? targetReps,
    ),
    ExerciseType.timed => SetValues(
      weightKg: source?.weightKg,
      durationSec: source?.durationSec ?? targetDurationSec,
    ),
  };
}
