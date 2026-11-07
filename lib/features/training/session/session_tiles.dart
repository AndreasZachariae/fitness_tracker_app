import 'package:flutter/material.dart';

import '../../../core/format/exercise_format.dart';
import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/gym_colors.dart';
import '../../../domain/metrics.dart';
import '../../../domain/models/models.dart';
import '../../../domain/prefill.dart';
import '../../../domain/progression.dart';
import '../../../domain/records.dart';
import '../../../domain/weight_steps.dart';
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
  Future<void> editNote(SessionExerciseDetail detail);
}

/// Short red highlight of a tile that just set a record (SPEC §7.7).
class _RecordHighlight extends StatelessWidget {
  const _RecordHighlight({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gym = GymColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 13, vertical: 1),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius + 3),
        color: active ? gym.recordContainer : Colors.transparent,
      ),
      child: child,
    );
  }
}

/// Small red "Rekord" label.
class RecordLabel extends StatelessWidget {
  const RecordLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final gym = GymColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: gym.recordContainer,
        borderRadius: BorderRadius.circular(AppTheme.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 14, color: gym.onRecordContainer),
          const SizedBox(width: 4),
          Text(
            S.record,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: gym.onRecordContainer,
            ),
          ),
        ],
      ),
    );
  }
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
  const _SetRows({
    required this.detail,
    required this.actions,
    required this.records,
  });

  final SessionExerciseDetail detail;
  final SessionTileActions actions;
  final Map<int, List<RecordKind>> records;

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
                      formatSingleSet(
                        detail.exercise.type,
                        set,
                        levels: levelsOf(detail.exercise),
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (records.containsKey(set.id)) ...[
                    const RecordLabel(),
                    const SizedBox(width: 8),
                  ],
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
    required this.step,
    this.records = const {},
    this.highlight = false,
    super.key,
  });

  final SessionExerciseDetail detail;
  final int index;
  final LastPerformance? last;
  final SessionTileActions actions;

  /// Weight step of the exercise with the settings (1.1.0).
  final WeightStep step;
  final Map<int, List<RecordKind>> records;

  /// Red flash after a record.
  final bool highlight;

  @override
  State<ActiveExerciseCard> createState() => _ActiveExerciseCardState();
}

class _ActiveExerciseCardState extends State<ActiveExerciseCard> {
  late SetValues _values = _prefill();
  bool _saving = false;

  /// The suggestion chip was applied or dismissed (SPEC §7.2).
  bool _suggestionDone = false;

  ProgressionSuggestion? get _suggestion {
    final d = widget.detail;
    if (_suggestionDone || d.sets.isNotEmpty) return null;
    final se = d.sessionExercise;
    return suggestProgression(
      type: d.exercise.type,
      step: widget.step,
      targetSets: se.targetSets,
      targetReps: se.targetReps,
      targetDurationSec: se.targetDurationSec,
      lastSessionSets: widget.last?.sets ?? const [],
    );
  }

  String _suggestionText(ProgressionSuggestion s) => switch (s) {
    AddWeight(step: LevelStep())
        when widget.detail.exercise.type == ExerciseType.weightReps =>
      S.plusOneLevel,
    final AddWeight a => '+${formatKg(a.deltaFrom(_values.weightKg ?? 0))}',
    AddRep() => S.plusOneRep,
    AddDuration(:final seconds) => '+$seconds ${S.secondsUnit}',
  };

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
      final w = await askWeight(
        context,
        null,
        levels: levelsOf(widget.detail.exercise),
      );
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
    final suggestion = _suggestion;
    final notes = d.exercise.notes;

    return _RecordHighlight(
      active: widget.highlight,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
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
                        Text(
                          d.exercise.name,
                          style: theme.textTheme.titleLarge,
                        ),
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
                padding: const EdgeInsets.only(right: 16, top: 4),
                child: notes.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.note_add_outlined, size: 18),
                          label: const Text(S.addNote),
                          onPressed: () => widget.actions.editNote(d),
                        ),
                      )
                    : InkWell(
                        onTap: () => widget.actions.editNote(d),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppTheme.minTouchTarget,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sticky_note_2_outlined,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  notes,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                          formatSetsDetailed(
                            d.exercise.type,
                            last.sets,
                            levels: levelsOf(d.exercise),
                          ),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (d.sets.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _SetRows(
                        detail: d,
                        actions: widget.actions,
                        records: widget.records,
                      ),
                    ],
                    if (suggestion != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InputChip(
                          avatar: const Icon(Icons.trending_up),
                          label: Text(
                            S.suggestion(_suggestionText(suggestion)),
                          ),
                          onPressed: () => setState(() {
                            _values = suggestion.applyTo(_values);
                            _suggestionDone = true;
                          }),
                          deleteButtonTooltipMessage: S.dismissSuggestion,
                          onDeleted: () =>
                              setState(() => _suggestionDone = true),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SetInput(
                      type: d.exercise.type,
                      step: widget.step,
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
    this.records = const {},
    this.highlight = false,
    super.key,
  });

  final SessionExerciseDetail detail;
  final bool expanded;
  final VoidCallback onToggle;
  final SessionTileActions actions;
  final Map<int, List<RecordKind>> records;
  final bool highlight;

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
        : S.doneSummary(
            detail.sets.length,
            formatSingleSet(e.type, best, levels: levelsOf(e)),
          );

    final hasRecord = detail.sets.any((s) => records.containsKey(s.id));
    return _RecordHighlight(
      active: highlight,
      child: Opacity(
        opacity: expanded || highlight ? 1 : 0.6,
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 2),
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
                      if (hasRecord) ...[
                        const RecordLabel(),
                        const SizedBox(width: 8),
                      ],
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
                      _SetRows(
                        detail: detail,
                        actions: actions,
                        records: records,
                      ),
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
      ),
    );
  }
}
