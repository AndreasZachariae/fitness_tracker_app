import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../core/router.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../../domain/session_rules.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/dashed_add_button.dart';
import '../../../widgets/haptics.dart';
import '../../../widgets/snackbars.dart';
import '../../../widgets/ticker.dart';
import '../../settings/exercises/exercise_form_page.dart';
import '../exercise_picker_sheet.dart';
import 'session_tiles.dart';
import 'set_edit_dialog.dart';

/// The running session (SPEC §6.2). Everything shown comes from the
/// database, so after an app restart the view is exactly as before.
class SessionView extends ConsumerStatefulWidget {
  const SessionView({required this.session, super.key});

  final Session session;

  @override
  ConsumerState<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends ConsumerState<SessionView>
    implements SessionTileActions {
  final _expanded = <int>{};
  List<int>? _pendingOrder;
  bool _finishing = false;

  Session get _session => widget.session;

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Future<void> saveSet(SessionExerciseDetail detail, SetValues values) =>
      _guard(() async {
        final repo = ref.read(sessionRepositoryProvider);
        final saved = await repo.saveSet(detail.sessionExercise.id, values);
        await lightHaptic();
        if (!mounted) return;
        showMessage(
          context,
          S.setSaved,
          onUndo: () => _guard(() => repo.undoSave(saved)),
        );
      });

  @override
  Future<void> activateExercise(SessionExerciseDetail detail) =>
      _guard(() async {
        _expanded.remove(detail.sessionExercise.id);
        await ref
            .read(sessionRepositoryProvider)
            .activate(detail.sessionExercise.id);
      });

  @override
  Future<void> addTargetSet(SessionExerciseDetail detail) => _guard(
    () => ref
        .read(sessionRepositoryProvider)
        .addTargetSet(detail.sessionExercise.id),
  );

  @override
  Future<void> skip(SessionExerciseDetail detail) => _guard(
    () => ref.read(sessionRepositoryProvider).skip(detail.sessionExercise.id),
  );

  @override
  Future<void> finishExercise(SessionExerciseDetail detail) => _guard(
    () => ref
        .read(sessionRepositoryProvider)
        .finishExercise(detail.sessionExercise.id),
  );

  @override
  Future<void> editSet(SessionExerciseDetail detail, SetEntry set) async {
    final result = await showSetEditDialog(
      context,
      exercise: detail.exercise,
      set: set,
    );
    if (result == null) return;
    final repo = ref.read(sessionRepositoryProvider);
    await _guard(() async {
      switch (result) {
        case SetEditSave(:final values):
          await repo.updateSet(set.id, values);
        case SetEditDelete():
          await repo.deleteSet(set.id);
          if (mounted) showMessage(context, S.setDeleted);
      }
    });
  }

  Future<void> _reorder(
    List<SessionExerciseDetail> details,
    int oldIndex,
    int newIndex,
  ) async {
    final ids = reorderSessionExercises(
      [for (final d in details) d.sessionExercise],
      oldIndex,
      newIndex,
    );
    if (ids == null) return;
    setState(() => _pendingOrder = ids);
    await _guard(
      () =>
          ref.read(sessionRepositoryProvider).reorderSession(_session.id, ids),
    );
    if (mounted) setState(() => _pendingOrder = null);
  }

  Future<void> _add(List<SessionExerciseDetail> details) async {
    final result = await showExercisePicker(
      context,
      containedIds: {for (final d in details) d.exercise.id},
    );
    if (result == null || !mounted) return;
    final defaults = ref.read(settingsProvider).value ?? AppSettings.defaults;
    final (int, ExerciseTargets)? toAdd = switch (result) {
      PickedExercise(:final exercise) => (
        exercise.id,
        ExerciseTargets(sets: defaults.defaultSets),
      ),
      CreateExercise(:final initialName) => await openExerciseForm(
        context,
        withTargets: true,
        initialName: initialName,
      ).then((r) => r == null ? null : (r.exerciseId, r.targets!)),
    };
    if (toAdd == null) return;
    await _guard(
      () => ref
          .read(sessionRepositoryProvider)
          .addExerciseToSession(_session.id, toAdd.$1, toAdd.$2),
    );
  }

  /// "Beenden" (SPEC §6.3).
  Future<void> _finish(List<SessionExerciseDetail> details) async {
    final repo = ref.read(sessionRepositoryProvider);
    final setCount = details.fold<int>(0, (n, d) => n + d.sets.length);
    if (setCount == 0) {
      final discard = await showConfirmDialog(
        context,
        title: S.discardNoSetsTitle,
        confirmLabel: S.discard,
        cancelLabel: S.keepTraining,
        destructive: true,
      );
      if (!discard) return;
      await _guard(() async {
        await repo.delete(_session.id);
        if (mounted) showMessage(context, S.trainingDiscarded);
      });
      return;
    }
    final open = details.where((d) => isMovable(d.sessionExercise.status));
    if (open.isNotEmpty) {
      final finish = await showConfirmDialog(
        context,
        title: S.openExercisesTitle(open.length),
        confirmLabel: S.finishTraining,
        cancelLabel: S.keepTraining,
      );
      if (!finish) return;
    }
    setState(() => _finishing = true);
    try {
      await repo.finishSession(_session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await context.push(AppRoutes.summary(_session.id));
      }
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loaded = ref.watch(sessionDetailsProvider(_session.id)).value;
    final last = ref.watch(lastPerformancesProvider).value ?? const {};
    var details = loaded ?? const <SessionExerciseDetail>[];
    final order = _pendingOrder;
    if (order != null && order.length == details.length) {
      final byId = {for (final d in details) d.sessionExercise.id: d};
      if (order.every(byId.containsKey)) {
        details = [for (final id in order) byId[id]!];
      }
    }

    final exercises = [for (final d in details) d.sessionExercise];
    final hasActive = exercises.any(
      (e) => e.status == SessionExerciseStatus.active,
    );
    int? nextId;
    if (!hasActive) {
      final completed = exercises.where((e) => e.completedAt != null).toList()
        ..sort((a, b) => a.completedAt!.compareTo(b.completedAt!));
      nextId = nextPendingExercise(
        exercises,
        afterId: completed.isEmpty ? null : completed.last.id,
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        // Name and timer share the title area: the name shortens first, the
        // timer only shrinks in extreme cases (e.g. a 13 h forgotten session).
        title: Row(
          children: [
            Expanded(
              child: Text(
                _session.planNameSnapshot ?? S.freeTrainingTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: ClockTicker(
                  builder: (context, now) => Text(
                    formatHms(now.difference(_session.startedAt)),
                    // Already 32 sp; not scaled further.
                    textScaler: TextScaler.noScaling,
                    style: NumberStyles.medium.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 16),
              ),
              onPressed: _finishing || loaded == null
                  ? null
                  : () => _finish(details),
              child: const Text(S.finishTraining),
            ),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: DashedAddButton(
            label: S.addExercise,
            onPressed: () => _add(details),
          ),
        ),
        itemCount: details.length,
        onReorderItem: (a, b) => _reorder(details, a, b),
        itemBuilder: (context, i) {
          final d = details[i];
          final key = ValueKey(d.sessionExercise.id);
          return switch (d.sessionExercise.status) {
            SessionExerciseStatus.active => ActiveExerciseCard(
              key: key,
              detail: d,
              index: i,
              last: last[d.exercise.id],
              actions: this,
            ),
            SessionExerciseStatus.pending => PendingExerciseTile(
              key: key,
              detail: d,
              index: i,
              isNext: d.sessionExercise.id == nextId,
              onTap: () => activateExercise(d),
            ),
            SessionExerciseStatus.done ||
            SessionExerciseStatus.skipped => CompletedExerciseTile(
              key: key,
              detail: d,
              expanded: _expanded.contains(d.sessionExercise.id),
              onToggle: () => setState(() {
                final id = d.sessionExercise.id;
                if (!_expanded.remove(id)) _expanded.add(id);
              }),
              actions: this,
            ),
          };
        },
      ),
    );
  }
}
