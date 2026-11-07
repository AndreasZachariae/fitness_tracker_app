import 'package:flutter/material.dart';

import '../../core/format/exercise_format.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/theme/gym_colors.dart';
import '../../domain/groups.dart';
import '../../domain/models/models.dart';
import '../../domain/weight_steps.dart';
import '../../widgets/dashed_add_button.dart';
import '../../widgets/exercise_type_icon.dart';
import '../../widgets/group_frame.dart';
import 'training_item.dart';

/// Reorderable list of the exercises before a session (SPEC §6.1) with
/// supersets and rotations as framed groups (M9): a group moves as a whole
/// at its header handle, its exercises move inside it.
class TrainingList extends StatefulWidget {
  const TrainingList({
    required this.items,
    required this.groups,
    required this.lastPerformances,
    required this.emptyText,
    required this.onReorder,
    required this.onRemove,
    required this.onTap,
    required this.onAdd,
    required this.groupKinds,
    required this.onCreateGroup,
    required this.onGroupOptions,
    this.loading = false,
    super.key,
  });

  final List<TrainingItem> items;
  final Map<int, TrainingGroup> groups;
  final Map<int, LastPerformance> lastPerformances;
  final String emptyText;

  /// While the list is loading, the empty text is not shown (no flicker
  /// when switching plans).
  final bool loading;

  /// New order of all items.
  final Future<void> Function(List<TrainingItem> ordered) onReorder;
  final Future<void> Function(TrainingItem item) onRemove;
  final ValueChanged<TrainingItem> onTap;
  final VoidCallback onAdd;

  /// Which "… erstellen" buttons are shown below "+ Übung hinzufügen".
  final List<PlanGroupKind> groupKinds;
  final ValueChanged<PlanGroupKind> onCreateGroup;
  final void Function(TrainingGroup group, List<TrainingItem> members)
  onGroupOptions;

  @override
  State<TrainingList> createState() => _TrainingListState();
}

class _TrainingListState extends State<TrainingList> {
  /// Order right after a drag, until the source catches up.
  List<TrainingItem>? _pendingOrder;

  /// Dismissed items are hidden at once; the removal itself is async.
  final _hidden = <Object>{};

  /// Group held at its drag handle, shown as one line (1.0.1).
  int? _held;

  void _hold(int? groupKey) {
    if (_held != groupKey) setState(() => _held = groupKey);
  }

  @override
  void didUpdateWidget(TrainingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) _pendingOrder = null;
  }

  Future<void> _apply(List<TrainingItem> ordered) {
    setState(() => _pendingOrder = ordered);
    return widget.onReorder(ordered);
  }

  Future<void> _dismiss(TrainingItem item) async {
    setState(() => _hidden.add(item.key));
    try {
      await widget.onRemove(item);
    } finally {
      if (mounted) setState(() => _hidden.remove(item.key));
    }
  }

  int? _groupOf(TrainingItem i) =>
      widget.groups.containsKey(i.groupKey) ? i.groupKey : null;

  Widget _dismissible(TrainingItem item, Widget child) {
    final theme = Theme.of(context);
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
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = (_pendingOrder ?? widget.items)
        .where((i) => !_hidden.contains(i.key))
        .toList();
    final blocks = blocksOf(items, _groupOf);

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 16),
      header: items.isEmpty && !widget.loading
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
      footer: widget.loading
          ? null
          : _Footer(
              groupKinds: widget.groupKinds,
              onAdd: widget.onAdd,
              onCreateGroup: widget.onCreateGroup,
            ),
      itemCount: blocks.length,
      onReorderEnd: (_) => _hold(null),
      onReorderItem: (a, b) {
        final moved = [...blocks];
        moved.insert(b, moved.removeAt(a));
        _apply(flatten(moved));
      },
      itemBuilder: (context, i) {
        final block = blocks[i];
        if (!block.isGroup) {
          final item = block.first;
          return KeyedSubtree(
            key: ValueKey(item.key),
            child: _dismissible(
              item,
              _TrainingTile(
                item: item,
                index: i,
                last: widget.lastPerformances[item.exercise.id],
                onTap: () => widget.onTap(item),
              ),
            ),
          );
        }
        final group = widget.groups[block.groupId]!;
        final members = block.items;
        final due = group.kind == PlanGroupKind.rotation
            ? group.dueIndex(members)
            : null;
        return GroupFrame(
          key: ValueKey('group-${group.key}'),
          kind: group.kind,
          subtitle: switch (group.kind) {
            PlanGroupKind.superset => supersetSubtitle(group.restSec),
            PlanGroupKind.rotation => S.rotationEvery(group.rotationEvery),
          },
          dragHandle: GroupDragHandle(
            kind: group.kind,
            index: i,
            onHold: () => _hold(group.key),
            onRelease: () => _hold(null),
          ),
          onOptions: () => widget.onGroupOptions(group, members),
          collapsedText: _held == group.key
              ? groupCollapsedText(members.map((m) => m.exercise.name))
              : null,
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: members.length,
            onReorderItem: (a, b) {
              final inner = [...members];
              inner.insert(b, inner.removeAt(a));
              _apply(
                flatten([
                  for (final x in blocks)
                    identical(x, block) ? Block(x.groupId, inner) : x,
                ]),
              );
            },
            itemBuilder: (context, k) {
              final item = members[k];
              return KeyedSubtree(
                key: ValueKey(item.key),
                child: _dismissible(
                  item,
                  _TrainingTile(
                    item: item,
                    index: k,
                    last: widget.lastPerformances[item.exercise.id],
                    onTap: () => widget.onTap(item),
                    rotationLabel: due == null
                        ? null
                        : k == due
                        ? (group.rotationEvery > 1
                              ? S.rotationDueLeft(
                                  group.rotationEvery - group.rotationDone,
                                )
                              : S.rotationDue)
                        : S.rotationLater,
                    dimmed: due != null && k != due,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.groupKinds,
    required this.onAdd,
    required this.onCreateGroup,
  });

  final List<PlanGroupKind> groupKinds;
  final VoidCallback onAdd;
  final ValueChanged<PlanGroupKind> onCreateGroup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          DashedAddButton(label: S.addExercise, onPressed: onAdd),
          Row(
            spacing: 8,
            children: [
              for (final kind in groupKinds)
                Expanded(
                  child: DashedAddButton(
                    label: S.createGroup(kind),
                    icon: groupIcon(kind),
                    color: groupColors(context, kind).$1,
                    onPressed: () => onCreateGroup(kind),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainingTile extends StatelessWidget {
  const _TrainingTile({
    required this.item,
    required this.index,
    required this.last,
    required this.onTap,
    this.rotationLabel,
    this.dimmed = false,
  });

  final TrainingItem item;
  final int index;
  final LastPerformance? last;
  final VoidCallback onTap;

  /// "Ist dran" / "Später" in a rotation.
  final String? rotationLabel;

  /// Rotation members that are not due are greyed out.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = item.exercise;
    final t = item.targets;
    final summary = last == null
        ? null
        : formatSetsSummary(e.type, last!.sets, levels: levelsOf(e));
    final rotation = GymColors.of(context).rotation;
    final tile = Card(
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
                    if (rotationLabel != null)
                      Text(
                        rotationLabel!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: dimmed
                              ? theme.colorScheme.onSurfaceVariant
                              : rotation,
                          fontWeight: FontWeight.w700,
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
    return dimmed ? Opacity(opacity: 0.55, child: tile) : tile;
  }
}
