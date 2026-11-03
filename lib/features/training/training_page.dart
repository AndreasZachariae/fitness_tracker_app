import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/settings_action.dart';
import '../../widgets/snackbars.dart';
import '../settings/exercises/exercise_form_page.dart';
import '../settings/plans/plan_actions.dart';
import 'active_session_placeholder.dart';
import 'exercise_picker_sheet.dart';
import 'free_training.dart';
import 'plan_chip_bar.dart';
import 'plan_entry_sheet.dart';
import 'training_item.dart';
import 'training_list.dart';

/// Tab "Training".
class TrainingPage extends ConsumerWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSessionProvider);
    return switch (active) {
      AsyncData(value: final session?) => ActiveSessionPlaceholder(
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

  AppSettings get _settings =>
      ref.read(settingsProvider).value ?? AppSettings.defaults;

  /// The selected plan, or `null` for "Frei" (also if it no longer exists).
  Plan? _selectedPlan(List<Plan> plans) {
    final id = ref.watch(settingsProvider).value?.lastSelectedPlanId;
    for (final p in plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<TrainingItem> _items(Plan? plan) {
    if (plan != null) {
      final entries = ref.watch(planEntriesProvider(plan.id)).value ?? const [];
      return [for (final e in entries) TrainingItem.fromPlanEntry(e)];
    }
    final exercises = ref.watch(exercisesByIdProvider).value ?? const {};
    return [
      for (final entry in ref.watch(freeTrainingProvider))
        if (exercises[entry.exerciseId] case final exercise?)
          TrainingItem(exercise: exercise, targets: entry.targets),
    ];
  }

  Future<void> _select(int? planId) async {
    try {
      await ref
          .read(settingsRepositoryProvider)
          .update((s) => s.copyWith(lastSelectedPlanId: planId));
    } on Object catch (e) {
      if (mounted) showError(context, e);
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

  Future<void> _add(Plan? plan, List<TrainingItem> items) async {
    final result = await showExercisePicker(
      context,
      containedIds: {for (final i in items) i.exercise.id},
    );
    if (result == null || !mounted) return;
    final (int, ExerciseTargets)? toAdd = switch (result) {
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
    if (toAdd == null || !mounted) return;
    final (exerciseId, targets) = toAdd;
    if (plan == null) {
      ref.read(freeTrainingProvider.notifier).add(exerciseId, targets);
      return;
    }
    try {
      await ref
          .read(planRepositoryProvider)
          .addExercise(
            plan.id,
            exerciseId,
            targetSets: targets.sets,
            targetReps: targets.reps,
            targetDurationSec: targets.durationSec,
            restSec: targets.restSec,
          );
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _reorder(Plan? plan, List<TrainingItem> ordered) async {
    if (plan == null) {
      ref.read(freeTrainingProvider.notifier).reorderTo([
        for (final i in ordered) i.exercise.id,
      ]);
      return;
    }
    try {
      await ref.read(planRepositoryProvider).reorderEntries(plan.id, [
        for (final i in ordered) i.planExercise!.id,
      ]);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
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

  Future<void> _edit(Plan? plan, TrainingItem item) async {
    final result = await showPlanEntrySheet(
      context,
      exercise: item.exercise,
      targets: item.targets,
      defaultRestSec: _settings.defaultRestSec,
      isPlan: plan != null,
      onChanged: (t) => _saveTargets(plan, item, t),
    );
    if (result == PlanEntrySheetResult.editExercise && mounted) {
      await openExerciseForm(context, exercise: item.exercise);
    }
  }

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
    try {
      await ref
          .read(planRepositoryProvider)
          .updateEntry(
            item.planExercise!.copyWith(
              targetSets: t.sets,
              targetReps: t.reps,
              targetDurationSec: t.durationSec,
              restSec: t.restSec,
            ),
          );
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _start(Plan? plan, List<TrainingItem> items) async {
    setState(() => _starting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .start(plan: plan, exercises: [for (final i in items) i.toDraft()]);
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
    final items = _items(plan);
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
              lastPerformances: last,
              emptyText: plan == null ? S.freeEmpty : S.planEmpty,
              onReorder: (ordered) => _reorder(plan, ordered),
              onRemove: (item) => _remove(plan, item),
              onTap: (item) => _edit(plan, item),
              onAdd: () => _add(plan, items),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text(S.startTraining),
                onPressed: _starting ? null : () => _start(plan, items),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
