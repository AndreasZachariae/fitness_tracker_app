import '../../domain/models/models.dart';

/// One row of the training list before a session: a plan entry or an entry
/// of the free list.
final class TrainingItem {
  const TrainingItem({
    required this.exercise,
    required this.targets,
    this.planExercise,
  });

  final Exercise exercise;
  final ExerciseTargets targets;

  /// Set in plan mode.
  final PlanExercise? planExercise;

  /// Stable key: plan entry id, or exercise id in the free list.
  Object get key => planExercise?.id ?? 'free-${exercise.id}';

  factory TrainingItem.fromPlanEntry(PlanEntry entry) {
    final p = entry.planExercise;
    return TrainingItem(
      exercise: entry.exercise,
      planExercise: p,
      targets: ExerciseTargets(
        sets: p.targetSets,
        reps: p.targetReps,
        durationSec: p.targetDurationSec,
        restSec: p.restSec,
      ),
    );
  }

  SessionExerciseDraft toDraft() => SessionExerciseDraft(
    exerciseId: exercise.id,
    targetSets: targets.sets,
    targetReps: targets.reps,
    targetDurationSec: targets.durationSec,
    restSec: targets.restSec,
  );
}
