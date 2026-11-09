import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/group_frame.dart';
import '../../widgets/settings_action.dart';
import '../../widgets/snackbars.dart';
import '../settings/exercises/exercise_form_page.dart';
import '../settings/plans/plan_actions.dart';
import '../settings/plans/plan_page.dart';
import 'exercise_picker_sheet.dart';
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

/// SPEC §6.1: choose a plan, arrange exercises, start. Since 1.2.1 there is
/// no "Frei" any more: every training starts from a plan.
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

  /// The selected plan; the first one if none (or a deleted one) is
  /// stored; `null` only without plans.
  Plan? _selectedPlan(List<Plan> plans) {
    final stored = ref.watch(settingsProvider).value?.lastSelectedPlanId;
    // Once the stored value caught up, the pending one is no longer needed
    // (so changes from elsewhere, e.g. a restored backup, win again).
    if (_hasPending && stored == _pendingPlanId) _hasPending = false;
    final id = _hasPending ? _pendingPlanId : stored;
    for (final p in plans) {
      if (p.id == id) return p;
    }
    return plans.firstOrNull;
  }

  /// Items of the plan; `null` while it is loading.
  List<TrainingItem>? _items(Plan plan) {
    final entries = ref.watch(planEntriesProvider(plan.id));
    if (!entries.hasValue) return null;
    return [for (final e in entries.value!) TrainingItem.fromPlanEntry(e)];
  }

  Map<int, TrainingGroup> _groups(Plan plan) {
    final groups = ref.watch(planGroupsProvider(plan.id)).value ?? const {};
    return {for (final g in groups.values) g.id: TrainingGroup.fromPlan(g)};
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _select(int planId) async {
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

  /// "+ Plan": create, select, and straight on to its training days.
  Future<void> _createPlan() async {
    final id = await createPlanWithDialog(context, ref);
    if (id == null || !mounted) return;
    await _select(id);
    if (mounted) await openPlanPage(context, id);
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

  Future<void> _add(Plan plan, List<TrainingItem> items) async {
    final toAdd = await _pickNew(items);
    if (toAdd == null || !mounted) return;
    final (exerciseId, targets) = toAdd;
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

  Future<void> _reorder(Plan plan, List<TrainingItem> ordered) async {
    await _guard(
      () => ref.read(planRepositoryProvider).reorderEntries(plan.id, [
        for (final i in ordered) i.planExercise!.id,
      ]),
    );
  }

  Future<void> _remove(TrainingItem item) async {
    final name = item.exercise.name;
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
      isPlan: true,
      onChanged: (t) => _saveTargets(item, t),
      groupKind: group?.kind,
      canMakeDue: canMakeDue,
    );
    if (!mounted) return;
    switch (result) {
      case PlanEntrySheetResult.editExercise:
        await openExerciseForm(context, exercise: item.exercise);
      case PlanEntrySheetResult.removeFromGroup:
        await _guard(
          () => ref
              .read(planRepositoryProvider)
              .removeFromGroup(item.planExercise!.id),
        );
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

  Future<void> _saveTargets(TrainingItem item, ExerciseTargets t) async {
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
    Plan plan,
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
    // No snackbar: the new frame shows the result, and a snackbar would
    // cover "Training starten".
    await _guard(
      () => ref.read(planRepositoryProvider).createGroup(plan.id, kind, [
        for (final i in picked) i.planExercise!.id,
      ]),
    );
  }

  Future<void> _groupOptions(
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
            label: S.supersetRestOption,
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
    switch (option) {
      case _GroupAction.rest:
        final last = members.last.exercise.restSec ?? _settings.defaultRestSec;
        final choice = await showSupersetRestDialog(
          context,
          restSec: group.restSec,
          defaultRestSec: members.last.targets.restSec ?? last,
        );
        if (choice == null) return;
        await _guard(
          () => plans.updateGroup(
            group.planGroup!.copyWith(restSec: choice.restSec),
          ),
        );
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
        await _guard(
          () => plans.addExerciseToGroup(group.key, toAdd.$1, toAdd.$2),
        );
      case _GroupAction.dissolve:
        await _guard(() => plans.dissolveGroup(group.key));
    }
  }

  Future<void> _start(
    Plan plan,
    List<TrainingItem> items,
    Map<int, TrainingGroup> groups,
  ) async {
    setState(() => _starting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .start(plan: plan, exercises: sessionDrafts(items, groups));
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(plansProvider).value;
    final plan = plans == null ? null : _selectedPlan(plans);
    final chips = PlanChipBar(
      plans: plans ?? const [],
      selectedPlanId: plan?.id,
      onSelect: _select,
      onCreate: _createPlan,
      onLongPress: (p) => openPlanPage(context, p.id),
    );
    final appBar = AppBar(
      title: const Text(S.tabTraining),
      actions: const [SettingsAction()],
    );
    if (plan == null) {
      // Loading, or no plan yet (1.2.1: every training needs a plan).
      return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: appBar,
        body: plans == null
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  chips,
                  Expanded(
                    // Scrolls instead of overflowing behind the keyboard.
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const EmptyState(
                              icon: Icons.list_alt_outlined,
                              message: S.noPlansYet,
                            ),
                            FilledButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text(S.createFirstPlan),
                              onPressed: _createPlan,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      );
    }
    final loaded = _items(plan);
    final items = loaded ?? const <TrainingItem>[];
    final groups = _groups(plan);
    final last = ref.watch(lastPerformancesProvider).value ?? const {};

    return Scaffold(
      // No text field on this page; dialogs move above the keyboard on their
      // own. Resizing squeezed the page behind the "+ Plan" dialog (1.0.1).
      resizeToAvoidBottomInset: false,
      appBar: appBar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          chips,
          Expanded(
            child: TrainingList(
              key: ValueKey(plan.id),
              items: items,
              groups: groups,
              loading: loaded == null,
              lastPerformances: last,
              emptyText: S.planEmpty,
              onReorder: (ordered) => _reorder(plan, ordered),
              onRemove: _remove,
              onTap: (item) => _edit(item, groups, items),
              onAdd: () => _add(plan, items),
              groupKinds: PlanGroupKind.values,
              onCreateGroup: (kind) => _createGroup(plan, kind, items, groups),
              onGroupOptions: (group, members) =>
                  _groupOptions(group, members, items),
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
