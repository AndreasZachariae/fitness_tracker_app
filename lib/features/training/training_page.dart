import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/group_frame.dart';
import '../../widgets/settings_action.dart';
import '../../widgets/snackbars.dart';
import '../settings/exercises/exercise_form_page.dart';
import '../settings/plans/plan_actions.dart';
import 'exercise_picker_sheet.dart';
import 'free_training.dart';
import 'plan_chip_bar.dart';
import 'plan_entry_sheet.dart';
import 'session/session_view.dart';
import 'training_item.dart';
import 'training_list.dart';

/// Tab "Training".
class TrainingPage extends ConsumerWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSessionProvider);
    return switch (active) {
      AsyncData(value: final session?) => SessionView(
        key: ValueKey(session.id),
        session: session,
      ),
      AsyncData() => const _PlanningView(),
      _ => const Scaffold(body: SizedBox.shrink()),
    };
  }
}

enum _PlanMenuAction { rename, duplicate, delete }

/// SPEC §6.1: choose a plan (or "Frei"), arrange exercises, start.
class _PlanningView extends ConsumerStatefulWidget {
  const _PlanningView();

  @override
  ConsumerState<_PlanningView> createState() => _PlanningViewState();
}

class _PlanningViewState extends ConsumerState<_PlanningView> {
  bool _starting = false;

  /// Selection shown at once while it is being saved (no lag, M9).
  int? _pendingPlanId;
  bool _hasPending = false;

  AppSettings get _settings =>
      ref.read(settingsProvider).value ?? AppSettings.defaults;

  /// The selected plan, or `null` for "Frei" (also if it no longer exists).
  Plan? _selectedPlan(List<Plan> plans) {
    final stored = ref.watch(settingsProvider).value?.lastSelectedPlanId;
    // Once the stored value caught up, the pending one is no longer needed
    // (so changes from elsewhere, e.g. a restored backup, win again).
    if (_hasPending && stored == _pendingPlanId) _hasPending = false;
    final id = _hasPending ? _pendingPlanId : stored;
    for (final p in plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Items of the plan or the free list; `null` while a plan is loading.
  List<TrainingItem>? _items(Plan? plan) {
    if (plan != null) {
      final entries = ref.watch(planEntriesProvider(plan.id));
      if (!entries.hasValue) return null;
      return [for (final e in entries.value!) TrainingItem.fromPlanEntry(e)];
    }
    final exercises = ref.watch(exercisesByIdProvider).value ?? const {};
    return [
      for (final entry in ref.watch(freeTrainingProvider))
        if (exercises[entry.exerciseId] case final exercise?)
          TrainingItem(
            exercise: exercise,
            targets: entry.targets,
            groupKey: entry.supersetKey,
          ),
    ];
  }

  Map<int, TrainingGroup> _groups(Plan? plan) {
    if (plan != null) {
      final groups = ref.watch(planGroupsProvider(plan.id)).value ?? const {};
      return {for (final g in groups.values) g.id: TrainingGroup.fromPlan(g)};
    }
    final result = <int, TrainingGroup>{};
    for (final e in ref.watch(freeTrainingProvider)) {
      final key = e.supersetKey;
      if (key == null) continue;
      result[key] = TrainingGroup(
        key: key,
        kind: PlanGroupKind.superset,
        restSec: e.supersetRestSec,
      );
    }
    return result;
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _select(int? planId) async {
    setState(() {
      _pendingPlanId = planId;
      _hasPending = true;
    });
    try {
      await ref
          .read(settingsRepositoryProvider)
          .update((s) => s.copyWith(lastSelectedPlanId: planId));
    } on Object catch (e) {
      if (mounted) {
        setState(() => _hasPending = false);
        showError(context, e);
      }
    }
  }

  Future<void> _createPlan() async {
    final id = await createPlanWithDialog(context, ref);
    if (id != null) await _select(id);
  }

  Future<void> _planMenu(Plan plan) async {
    final action = await showModalBottomSheet<_PlanMenuAction>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text(S.rename),
              onTap: () => Navigator.pop(context, _PlanMenuAction.rename),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text(S.duplicate),
              onTap: () => Navigator.pop(context, _PlanMenuAction.duplicate),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                S.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, _PlanMenuAction.delete),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _PlanMenuAction.rename:
        await renamePlanWithDialog(context, ref, plan);
      case _PlanMenuAction.duplicate:
        final id = await duplicatePlanWithDialog(context, ref, plan);
        if (id != null) await _select(id);
      case _PlanMenuAction.delete:
        await deletePlanWithConfirmation(context, ref, plan);
    }
  }

  /// Picks an exercise (or creates one) that is not in the list yet.
  Future<(int, ExerciseTargets)?> _pickNew(List<TrainingItem> items) async {
    final result = await showExercisePicker(
      context,
      containedIds: {for (final i in items) i.exercise.id},
    );
    if (result == null || !mounted) return null;
    return switch (result) {
      PickedExercise(:final exercise) => (
        exercise.id,
        ExerciseTargets(sets: _settings.defaultSets),
      ),
      CreateExercise(:final initialName) => await openExerciseForm(
        context,
        withTargets: true,
        initialName: initialName,
      ).then((r) => r == null ? null : (r.exerciseId, r.targets!)),
    };
  }

  Future<void> _add(Plan? plan, List<TrainingItem> items) async {
    final toAdd = await _pickNew(items);
    if (toAdd == null || !mounted) return;
    final (exerciseId, targets) = toAdd;
    if (plan == null) {
      ref.read(freeTrainingProvider.notifier).add(exerciseId, targets);
      return;
    }
    await _guard(
      () => ref
          .read(planRepositoryProvider)
          .addExercise(
            plan.id,
            exerciseId,
            targetSets: targets.sets,
            targetReps: targets.reps,
            targetDurationSec: targets.durationSec,
            restSec: targets.restSec,
          ),
    );
  }

  Future<void> _reorder(Plan? plan, List<TrainingItem> ordered) async {
    if (plan == null) {
      ref.read(freeTrainingProvider.notifier).reorderTo([
        for (final i in ordered) i.exercise.id,
      ]);
      return;
    }
    await _guard(
      () => ref.read(planRepositoryProvider).reorderEntries(plan.id, [
        for (final i in ordered) i.planExercise!.id,
      ]),
    );
  }

  Future<void> _remove(Plan? plan, TrainingItem item) async {
    final name = item.exercise.name;
    if (plan == null) {
      final free = ref.read(freeTrainingProvider.notifier);
      final removed = free.remove(item.exercise.id);
      if (removed == null || !mounted) return;
      final (index, entry) = removed;
      showMessage(
        context,
        S.removedFromList(name),
        onUndo: () => free.insert(index, entry),
      );
      return;
    }
    final repo = ref.read(planRepositoryProvider);
    try {
      final removed = await repo.removeEntry(item.planExercise!.id);
      if (!mounted) return;
      showMessage(
        context,
        S.removedFromList(name),
        onUndo: () => repo.restoreEntry(removed).catchError((Object e) {
          if (mounted) showError(context, e);
        }),
      );
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _edit(
    Plan? plan,
    TrainingItem item,
    Map<int, TrainingGroup> groups,
    List<TrainingItem> items,
  ) async {
    final group = groups[item.groupKey];
    var canMakeDue = false;
    if (group?.kind == PlanGroupKind.rotation) {
      final members = [
        for (final i in items)
          if (i.groupKey == group!.key) i,
      ];
      canMakeDue = members.indexOf(item) != group!.dueIndex(members);
    }
    final result = await showPlanEntrySheet(
      context,
      exercise: item.exercise,
      targets: item.targets,
      defaultRestSec: _settings.defaultRestSec,
      isPlan: plan != null,
      onChanged: (t) => _saveTargets(plan, item, t),
      groupKind: group?.kind,
      canMakeDue: canMakeDue,
    );
    if (!mounted) return;
    switch (result) {
      case PlanEntrySheetResult.editExercise:
        await openExerciseForm(context, exercise: item.exercise);
      case PlanEntrySheetResult.removeFromGroup:
        if (plan == null) {
          ref
              .read(freeTrainingProvider.notifier)
              .removeFromSuperset(item.exercise.id);
        } else {
          await _guard(
            () => ref
                .read(planRepositoryProvider)
                .removeFromGroup(item.planExercise!.id),
          );
        }
      case PlanEntrySheetResult.makeDue:
        await _makeDue(group!, item);
      case null:
    }
  }

  Future<void> _makeDue(TrainingGroup group, TrainingItem item) => _guard(
    () => ref
        .read(planRepositoryProvider)
        .setRotationCurrent(group.key, item.exercise.id),
  );

  Future<void> _saveTargets(
    Plan? plan,
    TrainingItem item,
    ExerciseTargets t,
  ) async {
    if (plan == null) {
      ref
          .read(freeTrainingProvider.notifier)
          .updateTargets(item.exercise.id, t);
      return;
    }
    await _guard(
      () => ref
          .read(planRepositoryProvider)
          .updateEntry(
            item.planExercise!.copyWith(
              targetSets: t.sets,
              targetReps: t.reps,
              targetDurationSec: t.durationSec,
              restSec: t.restSec,
            ),
          ),
    );
  }

  /// "Superset erstellen" / "Rotation erstellen" (M9).
  Future<void> _createGroup(
    Plan? plan,
    PlanGroupKind kind,
    List<TrainingItem> items,
    Map<int, TrainingGroup> groups,
  ) async {
    final free = [
      for (final i in items)
        if (!groups.containsKey(i.groupKey)) i,
    ];
    final chosen = await showGroupCreateSheet(
      context,
      kind: kind,
      candidates: [for (final i in free) (key: i.key, exercise: i.exercise)],
    );
    if (chosen == null || !mounted) return;
    final picked = [
      for (final i in free)
        if (chosen.contains(i.key)) i,
    ];
    if (plan == null) {
      ref.read(freeTrainingProvider.notifier).createSuperset([
        for (final i in picked) i.exercise.id,
      ]);
      return;
    }
    // No snackbar: the new frame shows the result, and a snackbar would
    // cover "Training starten".
    await _guard(
      () => ref.read(planRepositoryProvider).createGroup(plan.id, kind, [
        for (final i in picked) i.planExercise!.id,
      ]),
    );
  }

  Future<void> _groupOptions(
    Plan? plan,
    TrainingGroup group,
    List<TrainingItem> members,
    List<TrainingItem> items,
  ) async {
    final option = await showGroupOptions<_GroupAction>(
      context,
      kind: group.kind,
      options: [
        if (group.kind == PlanGroupKind.superset)
          (
            icon: Icons.timer_outlined,
            label: S.supersetRestTitle,
            value: _GroupAction.rest,
          )
        else ...[
          (
            icon: Icons.autorenew,
            label: S.rotationMakeDue,
            value: _GroupAction.due,
          ),
          (
            icon: Icons.event_repeat,
            label: S.rotationEveryOption,
            value: _GroupAction.every,
          ),
        ],
        (icon: Icons.add, label: S.addExercise, value: _GroupAction.add),
        (icon: Icons.link_off, label: S.dissolve, value: _GroupAction.dissolve),
      ],
    );
    if (option == null || !mounted) return;
    final plans = ref.read(planRepositoryProvider);
    final free = ref.read(freeTrainingProvider.notifier);
    switch (option) {
      case _GroupAction.rest:
        final last = members.last.exercise.restSec ?? _settings.defaultRestSec;
        final choice = await showSupersetRestDialog(
          context,
          restSec: group.restSec,
          defaultRestSec: members.last.targets.restSec ?? last,
        );
        if (choice == null) return;
        if (plan == null) {
          free.setSupersetRest(group.key, choice.restSec);
        } else {
          await _guard(
            () => plans.updateGroup(
              group.planGroup!.copyWith(restSec: choice.restSec),
            ),
          );
        }
      case _GroupAction.every:
        final every = await showRotationEveryDialog(
          context,
          every: group.rotationEvery,
        );
        if (every == null) return;
        await _guard(
          () => plans.updateGroup(
            group.planGroup!.copyWith(rotationEvery: every),
          ),
        );
      case _GroupAction.due:
        final index = await showChooseExercise(
          context,
          title: S.rotationMakeDue,
          names: [for (final m in members) m.exercise.name],
        );
        if (index == null) return;
        await _makeDue(group, members[index]);
      case _GroupAction.add:
        final toAdd = await _pickNew(items);
        if (toAdd == null || !mounted) return;
        if (plan == null) {
          free.add(toAdd.$1, toAdd.$2, supersetKey: group.key);
        } else {
          await _guard(
            () => plans.addExerciseToGroup(group.key, toAdd.$1, toAdd.$2),
          );
        }
      case _GroupAction.dissolve:
        if (plan == null) {
          free.dissolveSuperset(group.key);
        } else {
          await _guard(() => plans.dissolveGroup(group.key));
        }
    }
  }

  Future<void> _start(
    Plan? plan,
    List<TrainingItem> items,
    Map<int, TrainingGroup> groups,
  ) async {
    setState(() => _starting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .start(plan: plan, exercises: sessionDrafts(items, groups));
      if (plan == null) ref.read(freeTrainingProvider.notifier).clear();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(plansProvider).value ?? const [];
    final plan = _selectedPlan(plans);
    final loaded = _items(plan);
    final items = loaded ?? const <TrainingItem>[];
    final groups = _groups(plan);
    final last = ref.watch(lastPerformancesProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.tabTraining),
        actions: const [SettingsAction()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlanChipBar(
            plans: plans,
            selectedPlanId: plan?.id,
            onSelect: _select,
            onCreate: _createPlan,
            onLongPress: _planMenu,
          ),
          Expanded(
            child: TrainingList(
              key: ValueKey(plan?.id ?? 'free'),
              items: items,
              groups: groups,
              loading: loaded == null,
              lastPerformances: last,
              emptyText: plan == null ? S.freeEmpty : S.planEmpty,
              onReorder: (ordered) => _reorder(plan, ordered),
              onRemove: (item) => _remove(plan, item),
              onTap: (item) => _edit(plan, item, groups, items),
              onAdd: () => _add(plan, items),
              groupKinds: plan == null
                  ? const [PlanGroupKind.superset]
                  : PlanGroupKind.values,
              onCreateGroup: (kind) => _createGroup(plan, kind, items, groups),
              onGroupOptions: (group, members) =>
                  _groupOptions(plan, group, members, items),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text(S.startTraining),
                onPressed: _starting || loaded == null
                    ? null
                    : () => _start(plan, items, groups),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _GroupAction { rest, every, due, add, dissolve }
