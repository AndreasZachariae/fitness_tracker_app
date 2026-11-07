import 'models/models.dart';
import 'weight_steps.dart';

/// A suggestion to increase the load for set 1 (SPEC §7.2). Only offered,
/// never applied automatically.
sealed class ProgressionSuggestion {
  const ProgressionSuggestion();

  SetValues applyTo(SetValues values);
}

/// One step more: the next plate, level or kg step (1.1.0).
final class AddWeight extends ProgressionSuggestion {
  const AddWeight(this.step);

  final WeightStep step;

  @override
  SetValues applyTo(SetValues v) =>
      v.copyWith(weightKg: step.up(v.weightKg ?? 0));

  /// How much heavier than [weight] the suggestion is.
  double deltaFrom(double weight) =>
      ((step.up(weight) - weight) * 100).round() / 100;
}

final class AddRep extends ProgressionSuggestion {
  const AddRep();

  @override
  SetValues applyTo(SetValues v) =>
      v.copyWith(reps: v.reps == null ? null : v.reps! + 1);
}

final class AddDuration extends ProgressionSuggestion {
  const AddDuration(this.seconds);

  final int seconds;

  @override
  SetValues applyTo(SetValues v) => v.copyWith(
    durationSec: v.durationSec == null ? null : v.durationSec! + seconds,
  );
}

/// Seconds added for timed exercises.
const durationProgressionStep = 5;

/// Suggests more load when the last session reached the target in at least
/// [targetSets] working sets and all of its working sets reached it.
ProgressionSuggestion? suggestProgression({
  required ExerciseType type,
  required WeightStep step,
  required int targetSets,
  required int? targetReps,
  required int? targetDurationSec,
  required List<SetEntry> lastSessionSets,
}) {
  final target = type == ExerciseType.timed ? targetDurationSec : targetReps;
  if (target == null) return null;
  final working = lastSessionSets.where((s) => !s.isWarmup).toList();
  if (working.isEmpty || working.length < targetSets) return null;
  final reached = working.every(
    (s) => type == ExerciseType.timed
        ? (s.durationSec ?? 0) >= target
        : (s.reps ?? 0) >= target,
  );
  if (!reached) return null;
  return switch (type) {
    ExerciseType.weightReps => AddWeight(step),
    ExerciseType.bodyweight =>
      working.any((s) => (s.weightKg ?? 0) > 0)
          ? AddWeight(step)
          : const AddRep(),
    ExerciseType.timed => const AddDuration(durationProgressionStep),
  };
}
