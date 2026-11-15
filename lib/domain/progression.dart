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

/// Why a step up is suggested (1.6.3), shown under the suggestion.
sealed class ProgressionReason {
  const ProgressionReason(this.sets);

  /// Number of working sets last time.
  final int sets;
}

/// All working sets last time were the same: "3 × 10 mit 60 kg".
final class SameSets extends ProgressionReason {
  const SameSets(
    super.sets, {
    required this.weightKg,
    required this.reps,
    required this.durationSec,
  });

  final double? weightKg;
  final int? reps;
  final int? durationSec;
}

/// All working sets reached the target of the plan: "mind. 10 Wdh".
final class TargetReached extends ProgressionReason {
  const TargetReached(super.sets, {required this.target});

  /// Reps, or seconds for timed exercises.
  final int target;
}

typedef Progression = ({
  ProgressionSuggestion suggestion,
  ProgressionReason reason,
});

/// Suggests one step more (SPEC §7.2; rule of 1.6.3, decided by the user)
/// when the last session has at least [targetSets] working sets and either
///
/// * all of them were the same (weight and reps, or weight and time), or
/// * a target is set and all of them reached it.
Progression? suggestProgression({
  required ExerciseType type,
  required WeightStep step,
  required int targetSets,
  required int? targetReps,
  required int? targetDurationSec,
  required List<SetEntry> lastSessionSets,
}) {
  final working = lastSessionSets.where((s) => !s.isWarmup).toList();
  if (working.isEmpty || working.length < targetSets) return null;
  final timed = type == ExerciseType.timed;
  int amount(SetEntry s) => (timed ? s.durationSec : s.reps) ?? 0;
  final first = working.first;
  bool sameWeight(SetEntry s) =>
      ((s.weightKg ?? 0) - (first.weightKg ?? 0)).abs() < 0.001;
  final ProgressionReason reason;
  if (amount(first) > 0 &&
      working.every((s) => sameWeight(s) && amount(s) == amount(first))) {
    reason = SameSets(
      working.length,
      weightKg: first.weightKg,
      reps: timed ? null : first.reps,
      durationSec: timed ? first.durationSec : null,
    );
  } else {
    final target = timed ? targetDurationSec : targetReps;
    if (target == null || !working.every((s) => amount(s) >= target)) {
      return null;
    }
    reason = TargetReached(working.length, target: target);
  }
  final ProgressionSuggestion suggestion = switch (type) {
    ExerciseType.weightReps => AddWeight(step),
    ExerciseType.bodyweight =>
      working.any((s) => (s.weightKg ?? 0) > 0)
          ? AddWeight(step)
          : const AddRep(),
    ExerciseType.timed => const AddDuration(durationProgressionStep),
  };
  return (suggestion: suggestion, reason: reason);
}
