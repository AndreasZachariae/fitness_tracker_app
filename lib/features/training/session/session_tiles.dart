import 'package:flutter/material.dart';

import '../../../core/format/exercise_format.dart';
import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/gym_colors.dart';
import '../../../domain/metrics.dart';
import '../../../domain/models/models.dart';
import '../../../domain/prefill.dart';
import '../../../widgets/exercise_type_icon.dart';
import 'set_input.dart';

/// Callbacks of the tiles, implemented by the session view.
abstract interface class SessionTileActions {
  Future<void> saveSet(SessionExerciseDetail detail, SetValues values);
  Future<void> activateExercise(SessionExerciseDetail detail);
  Future<void> addTargetSet(SessionExerciseDetail detail);
  Future<void> skip(SessionExerciseDetail detail);
  Future<void> finishExercise(SessionExerciseDetail detail);
  Future<void> editSet(SessionExerciseDetail detail, SetEntry set);
}

Widget _dragHandle(int index) => ReorderableDragStartListener(
  index: index,
  child: const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Icon(Icons.drag_handle, semanticLabel: S.dragToReorder),
  ),
);

/// Rows of the recorded sets ("1   60 kg × 10"); tap → change/delete.
class _SetRows extends StatelessWidget {
  const _SetRows({required this.detail, required this.actions});

  final SessionExerciseDetail detail;
  final SessionTileActions actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      children: [
        for (final set in detail.sets)
          InkWell(
            onTap: () => actions.editSet(detail, set),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppTheme.minTouchTarget,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${set.setIndex}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      formatSingleSet(detail.exercise.type, set),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Icon(Icons.edit_outlined, size: 18, color: muted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The expanded active exercise (SPEC §6.2): header, last time, sets,
/// input, "Satz speichern" and the small actions.
class ActiveExerciseCard extends StatefulWidget {
  const ActiveExerciseCard({
    required this.detail,
    required this.index,
    required this.last,
    required this.actions,
    super.key,
  });

  final SessionExerciseDetail detail;
  final int index;
  final LastPerformance? last;
  final SessionTileActions actions;

  @override
  State<ActiveExerciseCard> createState() => _ActiveExerciseCardState();
}

class _ActiveExerciseCardState extends State<ActiveExerciseCard> {
  late SetValues _values = _prefill();
  bool _saving = false;

  SetValues _prefill() {
    final se = widget.detail.sessionExercise;
    return prefillSet(
      type: widget.detail.exercise.type,
      currentSets: widget.detail.sets,
      lastSessionSets: widget.last?.sets ?? const [],
      targetReps: se.targetReps,
      targetDurationSec: se.targetDurationSec,
    );
  }

  @override
  void didUpdateWidget(ActiveExerciseCard old) {
    super.didUpdateWidget(old);
    final setsChanged = old.detail.sets.length != widget.detail.sets.length;
    final otherExercise =
        old.detail.sessionExercise.id != widget.detail.sessionExercise.id;
    if (setsChanged ||
        otherExercise ||
        (old.last == null) != (widget.last == null)) {
      _values = _prefill();
    }
  }

  /// Missing required values are asked for instead of showing an error.
  Future<SetValues?> _complete(SetValues v) async {
    final type = widget.detail.exercise.type;
    var values = v;
    if (type == ExerciseType.weightReps && values.weightKg == null) {
      final w = await askWeight(context, null);
      if (w == null || !mounted) return null;
      values = values.copyWith(weightKg: w);
    }
    if (type != ExerciseType.timed && values.reps == null) {
      final r = await askReps(context, null);
      if (r == null || !mounted) return null;
      values = values.copyWith(reps: r);
    }
    if (type == ExerciseType.timed && values.durationSec == null) {
      final d = await askDuration(context, null);
      if (d == null || !mounted) return null;
      values = values.copyWith(durationSec: d);
    }
    return values;
  }

  Future<void> _save() async {
    final values = await _complete(_values);
    if (values == null || !mounted) return;
    setState(() {
      _values = values;
      _saving = true;
    });
    try {
      await widget.actions.saveSet(widget.detail, values);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final d = widget.detail;
    final se = d.sessionExercise;
    final done = d.sets.length;
    final current = done + 1;
    final last = widget.last;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // "Raised" surface: lighter than the background in both modes.
        color: theme.brightness == Brightness.light
            ? theme.colorScheme.surfaceContainerLowest
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: gym.activeEdge, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 0, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.exercise.name, style: theme.textTheme.titleLarge),
                      Text(
                        S.setOf(current, se.targetSets),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ProgressDots(done: done, total: se.targetSets),
                    ],
                  ),
                ),
                _dragHandle(widget.index),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (last != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      S.lastTimeOn(
                        formatShortDate(last.sessionStartedAt),
                        formatSetsDetailed(d.exercise.type, last.sets),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (d.sets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SetRows(detail: d, actions: widget.actions),
                  ],
                  const SizedBox(height: 12),
                  SetInput(
                    type: d.exercise.type,
                    incrementKg: d.exercise.incrementKg,
                    values: _values,
                    onChanged: (v) => setState(() => _values = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text(S.saveSet),
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => widget.actions.addTargetSet(d),
                        child: const Text(S.addOneSet),
                      ),
                      TextButton(
                        onPressed: () => widget.actions.skip(d),
                        child: const Text(S.skip),
                      ),
                      if (done > 0)
                        TextButton(
                          onPressed: () => widget.actions.finishExercise(d),
                          child: const Text(S.finishExercise),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = total > done ? total : done;
    return Semantics(
      label: S.progress(done, total),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < done ? scheme.primary : null,
                border: Border.all(color: scheme.primary, width: 2),
              ),
            ),
        ],
      ),
    );
  }
}

/// A not yet active exercise; [isNext] marks the suggested next one.
class PendingExerciseTile extends StatelessWidget {
  const PendingExerciseTile({
    required this.detail,
    required this.index,
    required this.isNext,
    required this.onTap,
    super.key,
  });

  final SessionExerciseDetail detail;
  final int index;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = detail.exercise;
    final se = detail.sessionExercise;
    final target = formatTarget(
      e.type,
      sets: se.targetSets,
      reps: se.targetReps,
      durationSec: se.targetDurationSec,
    );
    final progress = detail.sets.isEmpty
        ? null
        : S.progress(detail.sets.length, se.targetSets);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: isNext
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 0, 10),
          child: Row(
            children: [
              ExerciseTypeIcon(e.type),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNext)
                      Text(
                        S.nextUp,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    Text(e.name, style: theme.textTheme.titleMedium),
                    Text(
                      progress == null ? target : '$target · $progress',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _dragHandle(index),
            ],
          ),
        ),
      ),
    );
  }
}

/// A done or skipped exercise: reduced, with check; expandable to view and
/// change its sets and to reopen it.
class CompletedExerciseTile extends StatelessWidget {
  const CompletedExerciseTile({
    required this.detail,
    required this.expanded,
    required this.onToggle,
    required this.actions,
    super.key,
  });

  final SessionExerciseDetail detail;
  final bool expanded;
  final VoidCallback onToggle;
  final SessionTileActions actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final e = detail.exercise;
    final skipped =
        detail.sessionExercise.status == SessionExerciseStatus.skipped;
    final best = bestSet(e.type, detail.sets);
    final summary = skipped
        ? S.skippedLabel
        : best == null
        ? S.sets(detail.sets.length)
        : S.doneSummary(detail.sets.length, formatSingleSet(e.type, best));

    return Opacity(
      opacity: expanded ? 1 : 0.6,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Icon(
                      skipped ? Icons.redo : Icons.check_circle,
                      color: skipped
                          ? theme.colorScheme.onSurfaceVariant
                          : gym.success,
                      semanticLabel: skipped ? S.skippedLabel : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name, style: theme.textTheme.titleMedium),
                          Text(summary, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SetRows(detail: detail, actions: actions),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.replay),
                      label: const Text(S.reopen),
                      onPressed: () => actions.activateExercise(detail),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
