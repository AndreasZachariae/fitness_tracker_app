import 'package:flutter/material.dart';

import '../core/format/exercise_format.dart';
import '../core/l10n/strings_de.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/gym_colors.dart';
import '../domain/models/models.dart';
import 'exercise_type_icon.dart';
import 'info_button.dart';
import 'number_stepper.dart';

/// Icon of a group kind: linked exercises / rotating exercises.
IconData groupIcon(PlanGroupKind kind) => switch (kind) {
  PlanGroupKind.superset => Icons.link,
  PlanGroupKind.rotation => Icons.autorenew,
};

/// Frame color and tinted background of a group kind.
(Color, Color) groupColors(BuildContext context, PlanGroupKind kind) {
  final gym = GymColors.of(context);
  return switch (kind) {
    PlanGroupKind.superset => (gym.superset, gym.supersetContainer),
    PlanGroupKind.rotation => (gym.rotation, gym.rotationContainer),
  };
}

/// A superset or rotation in a list (M9): colored frame on a tinted
/// background, header with symbol, name, [subtitle], explanation, options
/// and a drag handle for the whole group; the member tiles in [child].
class GroupFrame extends StatelessWidget {
  const GroupFrame({
    required this.kind,
    required this.child,
    this.subtitle,
    this.dragHandle,
    this.onOptions,
    super.key,
  });

  final PlanGroupKind kind;
  final String? subtitle;
  final Widget child;

  /// E.g. a [ReorderableDragStartListener] of the outer list.
  final Widget? dragHandle;
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, container) = groupColors(context, kind);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: container,
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius + 4),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 2),
                child: Row(
                  children: [
                    Icon(groupIcon(kind), color: color, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.groupKind(kind).toUpperCase(),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                        ],
                      ),
                    ),
                    InfoButton(
                      title: S.groupKind(kind),
                      text: S.groupInfo(kind),
                    ),
                    if (onOptions != null)
                      IconButton(
                        tooltip: S.groupOptions(kind),
                        icon: const Icon(Icons.more_vert),
                        onPressed: onOptions,
                      ),
                    ?dragHandle,
                  ],
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// The drag handle icon of a whole group.
class GroupDragHandle extends StatelessWidget {
  const GroupDragHandle({required this.kind, required this.index, super.key});

  final PlanGroupKind kind;
  final int index;

  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
    index: index,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
      child: Icon(Icons.drag_handle, semanticLabel: S.moveGroup(kind)),
    ),
  );
}

/// An exercise that can be put into a new group.
typedef GroupCandidate = ({Object key, Exercise exercise});

/// Lets the user pick at least two exercises for a new superset or
/// rotation. Returns the chosen keys in list order, `null` if cancelled.
Future<List<Object>?> showGroupCreateSheet(
  BuildContext context, {
  required PlanGroupKind kind,
  required List<GroupCandidate> candidates,
}) async {
  if (candidates.length < 2) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.createGroup(kind)),
        content: const Text(S.groupNeedsTwo),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(S.ok),
          ),
        ],
      ),
    );
    return null;
  }
  return showModalBottomSheet<List<Object>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _GroupCreateSheet(kind: kind, candidates: candidates),
  );
}

class _GroupCreateSheet extends StatefulWidget {
  const _GroupCreateSheet({required this.kind, required this.candidates});

  final PlanGroupKind kind;
  final List<GroupCandidate> candidates;

  @override
  State<_GroupCreateSheet> createState() => _GroupCreateSheetState();
}

class _GroupCreateSheetState extends State<_GroupCreateSheet> {
  final _chosen = <Object>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, _) = groupColors(context, widget.kind);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Icon(groupIcon(widget.kind), color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.createGroup(widget.kind),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                InfoButton(
                  title: S.groupKind(widget.kind),
                  text: S.groupInfo(widget.kind),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              S.groupCreateHint(widget.kind),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in widget.candidates)
                  CheckboxListTile(
                    value: _chosen.contains(c.key),
                    secondary: ExerciseTypeIcon(c.exercise.type),
                    title: Text(c.exercise.name),
                    onChanged: (v) => setState(() {
                      if (v ?? false) {
                        _chosen.add(c.key);
                      } else {
                        _chosen.remove(c.key);
                      }
                    }),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: theme.colorScheme.surface,
              ),
              icon: Icon(groupIcon(widget.kind)),
              label: Text(S.createGroup(widget.kind)),
              onPressed: _chosen.length < 2
                  ? null
                  : () => Navigator.of(context).pop([
                      for (final c in widget.candidates)
                        if (_chosen.contains(c.key)) c.key,
                    ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtitle of a superset: its rest after each round.
String supersetSubtitle(int? restSec) => restSec == null
    ? S.supersetRestDefault
    : S.supersetRest(formatDuration(restSec));

/// Result of [showSupersetRestDialog]: the new rest, `null` = default.
typedef RestChoice = ({int? restSec});

/// "Pause nach jeder Runde": 15-s steps, or the rest of the last exercise.
Future<RestChoice?> showSupersetRestDialog(
  BuildContext context, {
  required int? restSec,
  required int defaultRestSec,
}) => showDialog<RestChoice>(
  context: context,
  builder: (_) => _RestDialog(initial: restSec, defaultRestSec: defaultRestSec),
);

class _RestDialog extends StatefulWidget {
  const _RestDialog({required this.initial, required this.defaultRestSec});

  final int? initial;
  final int defaultRestSec;

  @override
  State<_RestDialog> createState() => _RestDialogState();
}

class _RestDialogState extends State<_RestDialog> {
  static const _step = 15;
  static const _max = 600;
  late int? _rest = widget.initial;

  @override
  Widget build(BuildContext context) {
    final shown = _rest ?? widget.defaultRestSec;
    return AlertDialog(
      title: const Text(S.supersetRestTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NumberStepper(
            label: S.fieldRestShort,
            valueText: formatDuration(shown),
            helper: _rest == null ? S.supersetRestDefault : null,
            onDecrement: shown > 0
                ? () => setState(() => _rest = (shown - _step).clamp(0, _max))
                : null,
            onIncrement: shown < _max
                ? () => setState(() => _rest = (shown + _step).clamp(0, _max))
                : null,
          ),
          if (_rest != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _rest = null),
                child: const Text(S.resetToDefault),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop((restSec: _rest)),
          child: const Text(S.save),
        ),
      ],
    );
  }
}

/// "Übung wechseln nach N Trainings" (1–10).
Future<int?> showRotationEveryDialog(
  BuildContext context, {
  required int every,
}) => showDialog<int>(
  context: context,
  builder: (_) => _EveryDialog(initial: every),
);

class _EveryDialog extends StatefulWidget {
  const _EveryDialog({required this.initial});

  final int initial;

  @override
  State<_EveryDialog> createState() => _EveryDialogState();
}

class _EveryDialogState extends State<_EveryDialog> {
  late int _every = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(S.rotationEveryTitle),
      content: NumberStepper(
        label: S.trainings(_every),
        valueText: '$_every',
        onDecrement: _every > minRotationEvery
            ? () => setState(() => _every--)
            : null,
        onIncrement: _every < maxRotationEvery
            ? () => setState(() => _every++)
            : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_every),
          child: const Text(S.save),
        ),
      ],
    );
  }
}

/// One option of a group menu.
typedef GroupOption<T> = ({IconData icon, String label, T value});

/// Bottom sheet with the options of a group.
Future<T?> showGroupOptions<T>(
  BuildContext context, {
  required PlanGroupKind kind,
  required List<GroupOption<T>> options,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  builder: (context) {
    final (color, _) = groupColors(context, kind);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(groupIcon(kind), color: color),
            title: Text(
              S.groupOptions(kind),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final o in options)
            ListTile(
              leading: Icon(o.icon),
              title: Text(o.label),
              onTap: () => Navigator.pop(context, o.value),
            ),
        ],
      ),
    );
  },
);

/// Lets the user choose one of [names]; returns its index.
Future<int?> showChooseExercise(
  BuildContext context, {
  required String title,
  required List<String> names,
}) => showModalBottomSheet<int>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final (i, n) in names.indexed)
          ListTile(title: Text(n), onTap: () => Navigator.pop(context, i)),
      ],
    ),
  ),
);
