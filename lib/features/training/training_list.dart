import 'package:flutter/material.dart';

import '../../core/format/exercise_format.dart';
import '../../core/l10n/strings_de.dart';
import '../../domain/models/models.dart';
import '../../widgets/dashed_add_button.dart';
import '../../widgets/exercise_type_icon.dart';
import 'training_item.dart';

/// Reorderable list of the exercises before a session (SPEC §6.1).
class TrainingList extends StatefulWidget {
  const TrainingList({
    required this.items,
    required this.lastPerformances,
    required this.emptyText,
    required this.onReorder,
    required this.onRemove,
    required this.onTap,
    required this.onAdd,
    super.key,
  });

  final List<TrainingItem> items;
  final Map<int, LastPerformance> lastPerformances;
  final String emptyText;

  /// New order of all items.
  final Future<void> Function(List<TrainingItem> ordered) onReorder;
  final Future<void> Function(TrainingItem item) onRemove;
  final ValueChanged<TrainingItem> onTap;
  final VoidCallback onAdd;

  @override
  State<TrainingList> createState() => _TrainingListState();
}

class _TrainingListState extends State<TrainingList> {
  /// Order right after a drag, until the source catches up.
  List<TrainingItem>? _pendingOrder;

  /// Dismissed items are hidden at once; the removal itself is async.
  final _hidden = <Object>{};

  @override
  void didUpdateWidget(TrainingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) _pendingOrder = null;
  }

  Future<void> _reorder(List<TrainingItem> items, int oldIndex, int newIndex) {
    final list = [...items];
    list.insert(newIndex, list.removeAt(oldIndex));
    setState(() => _pendingOrder = list);
    return widget.onReorder(list);
  }

  Future<void> _dismiss(TrainingItem item) async {
    setState(() => _hidden.add(item.key));
    try {
      await widget.onRemove(item);
    } finally {
      if (mounted) setState(() => _hidden.remove(item.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = (_pendingOrder ?? widget.items)
        .where((i) => !_hidden.contains(i.key))
        .toList();

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 16),
      header: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
              child: Text(
                widget.emptyText,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : null,
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: DashedAddButton(label: S.addExercise, onPressed: widget.onAdd),
      ),
      itemCount: items.length,
      onReorderItem: (a, b) => _reorder(items, a, b),
      itemBuilder: (context, i) {
        final item = items[i];
        return Dismissible(
          key: ValueKey(item.key),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: theme.colorScheme.errorContainer,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.remove,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ],
            ),
          ),
          onDismissed: (_) => _dismiss(item),
          child: _TrainingTile(
            item: item,
            index: i,
            last: widget.lastPerformances[item.exercise.id],
            onTap: () => widget.onTap(item),
          ),
        );
      },
    );
  }
}

class _TrainingTile extends StatelessWidget {
  const _TrainingTile({
    required this.item,
    required this.index,
    required this.last,
    required this.onTap,
  });

  final TrainingItem item;
  final int index;
  final LastPerformance? last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = item.exercise;
    final t = item.targets;
    final summary = last == null ? null : formatSetsSummary(e.type, last!.sets);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
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
                    Text(e.name, style: theme.textTheme.titleMedium),
                    Text(
                      formatTarget(
                        e.type,
                        sets: t.sets,
                        reps: t.reps,
                        durationSec: t.durationSec,
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (summary != null)
                      Text(
                        S.lastTime(summary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Icon(
                    Icons.drag_handle,
                    semanticLabel: S.dragToReorder,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
