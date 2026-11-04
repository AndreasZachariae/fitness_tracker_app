import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' hide Block;

import '../../../core/device.dart';
import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../core/router.dart';
import '../../../core/theme/gym_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../domain/groups.dart';
import '../../../domain/models/models.dart';
import '../../../domain/records.dart';
import '../../../domain/rest_timer.dart';
import '../../../domain/session_rules.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/dashed_add_button.dart';
import '../../../widgets/group_frame.dart';
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

  /// Session exercise that just set a record (red flash, SPEC §7.7).
  int? _flashId;
  Timer? _flashTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _flash(int sessionExerciseId) {
    _flashTimer?.cancel();
    setState(() => _flashId = sessionExerciseId);
    _flashTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _flashId = null);
    });
  }

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
        final feedback = ref.read(deviceFeedbackProvider);
        if (saved.records.isNotEmpty) {
          _flash(detail.sessionExercise.id);
          unawaited(feedback.record());
        } else {
          unawaited(feedback.setSaved());
        }
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

  @override
  Future<void> editNote(SessionExerciseDetail detail) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(initial: detail.exercise.notes),
    );
    if (text == null) return;
    await _guard(
      () => ref
          .read(exerciseRepositoryProvider)
          .update(detail.exercise.copyWith(notes: text)),
    );
  }

  Future<void> _applyOrder(List<int>? ids) async {
    if (ids == null) return;
    setState(() => _pendingOrder = ids);
    await _guard(
      () =>
          ref.read(sessionRepositoryProvider).reorderSession(_session.id, ids),
    );
    if (mounted) setState(() => _pendingOrder = null);
  }

  /// Superset options (M9).
  Future<void> _supersetOptions(
    SessionSuperset superset,
    List<SessionExerciseDetail> members,
    List<SessionExerciseDetail> details,
  ) async {
    final option = await showGroupOptions<_SupersetAction>(
      context,
      kind: PlanGroupKind.superset,
      options: [
        (
          icon: Icons.timer_outlined,
          label: S.supersetRestTitle,
          value: _SupersetAction.rest,
        ),
        (icon: Icons.add, label: S.addExercise, value: _SupersetAction.add),
        (
          icon: Icons.output,
          label: '${S.removeFromGroup(PlanGroupKind.superset)} …',
          value: _SupersetAction.remove,
        ),
        (
          icon: Icons.link_off,
          label: S.dissolve,
          value: _SupersetAction.dissolve,
        ),
      ],
    );
    if (option == null || !mounted) return;
    final repo = ref.read(sessionRepositoryProvider);
    switch (option) {
      case _SupersetAction.rest:
        final settings =
            ref.read(settingsProvider).value ?? AppSettings.defaults;
        final last = members.last;
        final choice = await showSupersetRestDialog(
          context,
          restSec: superset.restSec,
          defaultRestSec: restDurationSec(
            sessionExerciseRestSec: last.sessionExercise.restSec,
            exerciseRestSec: last.exercise.restSec,
            defaultRestSec: settings.defaultRestSec,
          ),
        );
        if (choice == null) return;
        await _guard(
          () => repo.updateSupersetRest(superset.id, choice.restSec),
        );
      case _SupersetAction.add:
        await _add(details, supersetId: superset.id);
      case _SupersetAction.remove:
        final index = await showChooseExercise(
          context,
          title: S.whichExercise,
          names: [for (final m in members) m.exercise.name],
        );
        if (index == null) return;
        await _guard(
          () => repo.removeFromSuperset(members[index].sessionExercise.id),
        );
      case _SupersetAction.dissolve:
        await _guard(() => repo.dissolveSuperset(superset.id));
    }
  }

  /// "Superset erstellen" in the running session (M9): open exercises that
  /// are not in a superset yet.
  Future<void> _createSuperset(List<SessionExerciseDetail> details) async {
    final free = [
      for (final d in details)
        if (d.sessionExercise.supersetId == null &&
            isMovable(d.sessionExercise.status))
          d,
    ];
    final chosen = await showGroupCreateSheet(
      context,
      kind: PlanGroupKind.superset,
      candidates: [
        for (final d in free) (key: d.sessionExercise.id, exercise: d.exercise),
      ],
    );
    if (chosen == null || !mounted) return;
    await _guard(
      () => ref
          .read(sessionRepositoryProvider)
          .createSuperset(_session.id, chosen.cast<int>()),
    );
  }

  Future<void> _add(
    List<SessionExerciseDetail> details, {
    int? supersetId,
  }) async {
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
          .addExerciseToSession(
            _session.id,
            toAdd.$1,
            toAdd.$2,
            supersetId: supersetId,
          ),
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
    final records =
        ref.watch(sessionRecordsProvider(_session.id)).value ?? const {};
    final supersets =
        ref.watch(sessionSupersetsProvider(_session.id)).value ?? const {};
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
      body: _buildList(details, last, records, supersets, nextId),
    );
  }

  Widget _tile(
    SessionExerciseDetail d,
    int index,
    Map<int, LastPerformance> last,
    Map<int, List<RecordKind>> records,
    int? nextId,
  ) {
    final key = ValueKey(d.sessionExercise.id);
    return switch (d.sessionExercise.status) {
      SessionExerciseStatus.active => ActiveExerciseCard(
        key: key,
        detail: d,
        index: index,
        last: last[d.exercise.id],
        actions: this,
        records: records,
        highlight: _flashId == d.sessionExercise.id,
      ),
      SessionExerciseStatus.pending => PendingExerciseTile(
        key: key,
        detail: d,
        index: index,
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
        records: records,
        highlight: _flashId == d.sessionExercise.id,
      ),
    };
  }

  Widget _buildList(
    List<SessionExerciseDetail> details,
    Map<int, LastPerformance> last,
    Map<int, List<RecordKind>> records,
    Map<int, SessionSuperset> supersets,
    int? nextId,
  ) {
    final blocks = blocksOf(
      details,
      (d) => supersets.containsKey(d.sessionExercise.supersetId)
          ? d.sessionExercise.supersetId
          : null,
    );
    List<Block<SessionExercise>> exerciseBlocks() => [
      for (final b in blocks)
        Block(b.groupId, [for (final d in b.items) d.sessionExercise]),
    ];
    final gym = GymColors.of(context);

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            DashedAddButton(
              label: S.addExercise,
              onPressed: () => _add(details),
            ),
            DashedAddButton(
              label: S.createGroup(PlanGroupKind.superset),
              icon: groupIcon(PlanGroupKind.superset),
              color: gym.superset,
              onPressed: () => _createSuperset(details),
            ),
          ],
        ),
      ),
      itemCount: blocks.length,
      onReorderItem: (a, b) =>
          _applyOrder(reorderSessionBlocks(exerciseBlocks(), a, b)),
      itemBuilder: (context, i) {
        final block = blocks[i];
        if (!block.isGroup) {
          return KeyedSubtree(
            key: ValueKey(block.first.sessionExercise.id),
            child: _tile(block.first, i, last, records, nextId),
          );
        }
        final superset = supersets[block.groupId]!;
        final members = block.items;
        final movable = members.every(
          (d) => isMovable(d.sessionExercise.status),
        );
        return GroupFrame(
          key: ValueKey('superset-${superset.id}'),
          kind: PlanGroupKind.superset,
          subtitle: _supersetSubtitle(superset, members),
          dragHandle: movable
              ? GroupDragHandle(kind: PlanGroupKind.superset, index: i)
              : null,
          onOptions: () => _supersetOptions(superset, members, details),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: members.length,
            onReorderItem: (a, b) {
              final inner = reorderKeepingFixed(
                [for (final d in members) d.sessionExercise],
                a,
                b,
                (e) => isMovable(e.status),
              );
              if (inner == null) return;
              _applyOrder([
                for (final x in exerciseBlocks())
                  ...(x.groupId == superset.id ? inner : x.items).map(
                    (e) => e.id,
                  ),
              ]);
            },
            itemBuilder: (context, k) => KeyedSubtree(
              key: ValueKey(members[k].sessionExercise.id),
              child: _tile(members[k], k, last, records, nextId),
            ),
          ),
        );
      },
    );
  }

  /// "Runde 2 von 3 · Pause 1:30 nach jeder Runde".
  String _supersetSubtitle(
    SessionSuperset superset,
    List<SessionExerciseDetail> members,
  ) {
    final rest = supersetSubtitle(superset.restSec);
    final open = [
      for (final d in members)
        if (hasSetsLeft(supersetMemberOf(d))) supersetMemberOf(d),
    ];
    if (open.isEmpty) return rest;
    final rounds = members
        .map((d) => d.sessionExercise.targetSets)
        .reduce((a, b) => a > b ? a : b);
    final round = open.map((m) => m.sets).reduce((a, b) => a < b ? a : b) + 1;
    return '${S.supersetRound(round.clamp(1, rounds), rounds)} · $rest';
  }
}

enum _SupersetAction { rest, add, remove, dissolve }

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.initial});

  final String initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(S.editNote),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: S.fieldNotesHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text(S.save),
        ),
      ],
    );
  }
}
