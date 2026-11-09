import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings_de.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/snackbars.dart';
import 'plan_actions.dart';
import 'plan_schedule_sheet.dart';

enum _PlanAction { schedule, rename, duplicate, delete }

/// Settings → Pläne: order of the plan chips and plan management.
class PlanListPage extends ConsumerStatefulWidget {
  const PlanListPage({super.key});

  @override
  ConsumerState<PlanListPage> createState() => _PlanListPageState();
}

class _PlanListPageState extends ConsumerState<PlanListPage> {
  /// Order shown right after a drag, until the database stream catches up.
  List<Plan>? _pending;

  Future<void> _reorder(List<Plan> plans, int oldIndex, int newIndex) async {
    // onReorderItem already adjusts newIndex for the removed item.
    final list = [...plans];
    list.insert(newIndex, list.removeAt(oldIndex));
    setState(() => _pending = list);
    try {
      await ref.read(planRepositoryProvider).reorder([
        for (final p in list) p.id,
      ]);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _pending = null);
  }

  Future<void> _onAction(_PlanAction action, Plan plan) async {
    switch (action) {
      case _PlanAction.schedule:
        await showPlanScheduleSheet(context, plan);
      case _PlanAction.rename:
        await renamePlanWithDialog(context, ref, plan);
      case _PlanAction.duplicate:
        await duplicatePlanWithDialog(context, ref, plan);
      case _PlanAction.delete:
        await deletePlanWithConfirmation(context, ref, plan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _pending ?? ref.watch(plansProvider).value;
    final counts = ref.watch(planEntryCountsProvider).value ?? const {};
    final schedules =
        ref.watch(planSchedulesProvider).value ?? const <PlanScheduleEntry>[];

    return Scaffold(
      appBar: AppBar(title: const Text(S.plansTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => createPlanWithDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text(S.newPlan),
      ),
      body: switch (plans) {
        null => const SizedBox.shrink(),
        [] => const EmptyState(
          icon: Icons.list_alt_outlined,
          message: S.plansEmpty,
        ),
        final list => ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          onReorderItem: (a, b) => _reorder(list, a, b),
          itemBuilder: (context, i) {
            final plan = list[i];
            return ListTile(
              key: ValueKey(plan.id),
              title: Text(
                plan.active ? plan.name : '${plan.name} (${S.planInactive})',
                style: plan.active
                    ? null
                    : TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
              ),
              subtitle: Text(
                '${S.exerciseCount(counts[plan.id] ?? 0)} · '
                '${formatPlanSchedule([for (final d in schedules)
                  if (d.planId == plan.id) d])}',
              ),
              onTap: () => showPlanScheduleSheet(context, plan),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<_PlanAction>(
                    tooltip: S.moreActions,
                    onSelected: (a) => _onAction(a, plan),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _PlanAction.schedule,
                        child: Text(S.planSchedule),
                      ),
                      PopupMenuItem(
                        value: _PlanAction.rename,
                        child: Text(S.rename),
                      ),
                      PopupMenuItem(
                        value: _PlanAction.duplicate,
                        child: Text(S.duplicate),
                      ),
                      PopupMenuItem(
                        value: _PlanAction.delete,
                        child: Text(S.delete),
                      ),
                    ],
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.drag_handle,
                        semanticLabel: S.dragToReorder,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      },
    );
  }
}
