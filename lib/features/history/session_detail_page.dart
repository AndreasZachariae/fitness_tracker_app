import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/format/exercise_format.dart';
import '../../core/format/formatters.dart';
import '../../core/l10n/error_messages.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/typography.dart';
import '../../data/providers.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/history.dart';
import '../../domain/models/models.dart';
import '../../domain/records.dart';
import '../../domain/weight_steps.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/exercise_type_icon.dart';
import '../../widgets/snackbars.dart';
import '../heart_rate/heart_rate_widgets.dart';
import '../training/session/session_tiles.dart' show RecordLabel;
import '../training/session/set_edit_dialog.dart';

/// Details of a finished session (SPEC §6.4).
class SessionDetailPage extends ConsumerStatefulWidget {
  const SessionDetailPage({required this.sessionId, super.key});

  final int sessionId;

  @override
  ConsumerState<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends ConsumerState<SessionDetailPage> {
  final _notes = TextEditingController();
  bool _notesLoaded = false;
  Timer? _debounce;

  /// Read once: `ref` must not be used in [dispose].
  late final SessionRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(sessionRepositoryProvider);
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      // Save pending text when leaving the page.
      _repo
          .updateNotes(widget.sessionId, _notes.text)
          .catchError((Object _) {});
    }
    _debounce?.cancel();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _onNotesChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 600),
      () => _guard(
        () => ref
            .read(sessionRepositoryProvider)
            .updateNotes(widget.sessionId, text),
      ),
    );
  }

  Future<void> _editTimes(Session session) async {
    final result = await showDialog<(DateTime, DateTime)>(
      context: context,
      builder: (_) => _TimesDialog(
        start: session.startedAt.toLocal(),
        end: session.endedAt!.toLocal(),
        now: ref.read(clockProvider).now(),
      ),
    );
    if (result == null) return;
    await _guard(
      () => ref
          .read(sessionRepositoryProvider)
          .updateSessionTimes(session.id, start: result.$1, end: result.$2),
    );
  }

  Future<void> _editSet(SessionExerciseDetail d, SetEntry set) async {
    final result = await showSetEditDialog(
      context,
      exercise: d.exercise,
      set: set,
      step: weightStepOf(
        d.exercise,
        ref.read(settingsProvider).value ?? AppSettings.defaults,
      ),
    );
    if (result == null) return;
    final repo = ref.read(sessionRepositoryProvider);
    await _guard(() async {
      switch (result) {
        case SetEditSave(:final values):
          await repo.updateSet(set.id, values);
        case SetEditDelete():
          await repo.deleteSet(set.id);
      }
    });
  }

  Future<void> _removeExercise(SessionExerciseDetail d) async {
    final ok = await showConfirmDialog(
      context,
      title: S.removeFromSessionTitle(d.exercise.name),
      body: S.removeFromSessionBody,
      confirmLabel: S.remove,
      destructive: true,
    );
    if (!ok) return;
    await _guard(() async {
      await ref
          .read(sessionRepositoryProvider)
          .removeSessionExercise(d.sessionExercise.id);
    });
  }

  Future<void> _delete(Session session) async {
    final ok = await showConfirmDialog(
      context,
      title: S.deleteSessionTitle(
        formatWeekdayDate(session.startedAt),
        session.planNameSnapshot ?? S.freeTrainingTitle,
      ),
      body: S.deleteSessionBody,
      confirmLabel: S.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    _debounce?.cancel(); // nothing left to save
    await _guard(() async {
      final repo = ref.read(sessionRepositoryProvider);
      final deleted = await repo.delete(session.id);
      if (!mounted) return;
      // The messenger outlives this page, so "Rückgängig" works in the list.
      final messenger = ScaffoldMessenger.of(context);
      showMessage(
        context,
        S.sessionDeleted,
        onUndo: () => repo.restoreDeleted(deleted).catchError((Object e) {
          messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
        }),
      );
      context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider(widget.sessionId)).value;
    final details =
        ref.watch(sessionDetailsProvider(widget.sessionId)).value ?? const [];
    final records =
        ref.watch(sessionRecordsProvider(widget.sessionId)).value ?? const {};
    if (session != null && !_notesLoaded) {
      _notes.text = session.notes;
      _notesLoaded = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session == null ? '' : formatWeekdayDateYear(session.startedAt),
        ),
        actions: [
          if (session != null)
            IconButton(
              tooltip: S.deleteSession,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(session),
            ),
        ],
      ),
      body: session == null || session.endedAt == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  session.planNameSnapshot ?? S.freeTrainingTitle,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                  onTap: () => _editTimes(session),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppTheme.minTouchTarget,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${formatClockTime(session.startedAt)} – '
                            '${formatClockTime(session.endedAt!)} · '
                            '${formatTrainingDuration(session.endedAt!.difference(session.startedAt))}',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Icon(
                          Icons.edit_outlined,
                          size: 20,
                          semanticLabel: S.editTimes,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: S.fieldNotes,
                    hintText: S.summaryNotesHint,
                  ),
                  onChanged: _onNotesChanged,
                ),
                const SizedBox(height: 12),
                // 1.5.0: only with a heart rate monitor.
                HeartRateSection(sessionId: session.id),
                if (details.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      S.sessionDetailEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final d in details)
                  _ExerciseCard(
                    detail: d,
                    records: records,
                    onEditSet: (set) => _editSet(d, set),
                    onRemove: () => _removeExercise(d),
                  ),
              ],
            ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.detail,
    required this.records,
    required this.onEditSet,
    required this.onRemove,
  });

  final SessionExerciseDetail detail;
  final Map<int, List<RecordKind>> records;
  final ValueChanged<SetEntry> onEditSet;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final e = detail.exercise;
    final skipped =
        detail.sessionExercise.status == SessionExerciseStatus.skipped;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExerciseTypeIcon(e.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name, style: theme.textTheme.titleMedium),
                      if (skipped)
                        Text(S.skippedLabel, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                PopupMenuButton<void>(
                  tooltip: S.moreActions,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: onRemove,
                      child: const Text(S.removeFromSession),
                    ),
                  ],
                ),
              ],
            ),
            if (detail.sets.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  S.noSetsRecorded,
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ),
            for (final set in detail.sets)
              InkWell(
                onTap: () => onEditSet(set),
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
                          style: NumberStyles.small.copyWith(
                            fontSize: 16,
                            color: muted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          formatSingleSet(e.type, set, levels: levelsOf(e)),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (set.hrTargetSec case final inTarget?) ...[
                        Text(
                          S.cardioTargetTime(
                            formatMinSec(Duration(seconds: inTarget)),
                          ),
                          key: const ValueKey('set-target-time'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (set.hrPeak case final peak?) ...[
                        SetHeartRateLabel(peak: peak),
                        const SizedBox(width: 8),
                      ],
                      if (records.containsKey(set.id)) const RecordLabel(),
                      const SizedBox(width: 12),
                      Icon(Icons.edit_outlined, size: 18, color: muted),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Start and end with date and time pickers.
class _TimesDialog extends StatefulWidget {
  const _TimesDialog({
    required this.start,
    required this.end,
    required this.now,
  });

  final DateTime start;
  final DateTime end;
  final DateTime now;

  @override
  State<_TimesDialog> createState() => _TimesDialogState();
}

class _TimesDialogState extends State<_TimesDialog> {
  late DateTime _start = widget.start;
  late DateTime _end = widget.end;

  String? get _error =>
      switch (validateSessionTimes(start: _start, end: _end, now: widget.now)) {
        SessionTimesError.endBeforeStart => S.errorEndBeforeStart,
        SessionTimesError.inFuture => S.errorEndInFuture,
        null => null,
      };

  Future<DateTime?> _pick(DateTime current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: widget.now.toLocal(),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _row(String label, DateTime value, ValueChanged<DateTime> onChanged) {
    return Row(
      children: [
        SizedBox(width: 56, child: Text(label)),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final picked = await _pick(value);
              if (picked != null) setState(() => onChanged(picked));
            },
            child: Text(
              '${formatWeekdayDate(value)} ${formatClockTime(value)}',
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: const Text(S.editTimes),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(S.start, _start, (v) => _start = v),
          const SizedBox(height: 8),
          _row(S.end, _end, (v) => _end = v),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          onPressed: error == null
              ? () => Navigator.of(context).pop((_start, _end))
              : null,
          child: const Text(S.save),
        ),
      ],
    );
  }
}
