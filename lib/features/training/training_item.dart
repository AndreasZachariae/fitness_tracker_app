import '../../domain/groups.dart';
import '../../domain/models/models.dart';

/// One row of the training list before a session: a plan entry or an entry
/// of the free list.
final class TrainingItem {
  const TrainingItem({
    required this.exercise,
    required this.targets,
    this.planExercise,
    this.groupKey,
  });

  final Exercise exercise;
  final ExerciseTargets targets;

  /// Set in plan mode.
  final PlanExercise? planExercise;

  /// Plan group id, or superset key of the free list (M9).
  final int? groupKey;

  /// Stable key: plan entry id, or exercise id in the free list.
  Object get key => planExercise?.id ?? 'free-${exercise.id}';

  factory TrainingItem.fromPlanEntry(PlanEntry entry) {
    final p = entry.planExercise;
    return TrainingItem(
      exercise: entry.exercise,
      planExercise: p,
      groupKey: p.groupId,
      targets: ExerciseTargets(
        sets: p.targetSets,
        reps: p.targetReps,
        durationSec: p.targetDurationSec,
        restSec: p.restSec,
      ),
    );
  }

  SessionExerciseDraft toDraft({int? supersetKey, int? supersetRestSec}) =>
      SessionExerciseDraft(
        exerciseId: exercise.id,
        targetSets: targets.sets,
        targetReps: targets.reps,
        targetDurationSec: targets.durationSec,
        restSec: targets.restSec,
        supersetKey: supersetKey,
        supersetRestSec: supersetRestSec,
      );
}

/// A superset or rotation of the training list (M9).
final class TrainingGroup {
  const TrainingGroup({
    required this.key,
    required this.kind,
    this.restSec,
    this.rotationEvery = 1,
    this.rotationDone = 0,
    this.rotationExerciseId,
    this.planGroup,
  });

  factory TrainingGroup.fromPlan(PlanGroup g) => TrainingGroup(
    key: g.id,
    kind: g.kind,
    restSec: g.restSec,
    rotationEvery: g.rotationEvery,
    rotationDone: g.rotationDone,
    rotationExerciseId: g.rotationExerciseId,
    planGroup: g,
  );

  final int key;
  final PlanGroupKind kind;
  final int? restSec;
  final int rotationEvery;
  final int rotationDone;
  final int? rotationExerciseId;

  /// Set in plan mode.
  final PlanGroup? planGroup;

  /// Index of the rotation member due in the next training.
  int dueIndex(List<TrainingItem> members) => rotationIndex([
    for (final m in members) m.exercise.id,
  ], rotationExerciseId);
}

/// The drafts of a session started from [items]: supersets keep their
/// members, a rotation contributes only the exercise that is due (M9).
List<SessionExerciseDraft> sessionDrafts(
  List<TrainingItem> items,
  Map<int, TrainingGroup> groups,
) {
  final drafts = <SessionExerciseDraft>[];
  for (final block in blocksOf(items, (i) => i.groupKey)) {
    final group = groups[block.groupId];
    switch (group?.kind) {
      case null:
        drafts.addAll(block.items.map((i) => i.toDraft()));
      case PlanGroupKind.superset:
        drafts.addAll(
          block.items.map(
            (i) => i.toDraft(
              supersetKey: group!.key,
              supersetRestSec: group.restSec,
            ),
          ),
        );
      case PlanGroupKind.rotation:
        drafts.add(block.items[group!.dueIndex(block.items)].toDraft());
    }
  }
  return drafts;
}
