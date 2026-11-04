import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/clock.dart';
import '../../../core/format/exercise_format.dart';
import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../core/router.dart';
import '../../../core/theme/gym_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../domain/metrics.dart';
import '../../../domain/models/models.dart';
import '../../../widgets/name_dialog.dart';
import '../../../widgets/snackbars.dart';
import '../../settings/data/data_actions.dart';

/// Data shown in the summary, loaded once.
final class _SummaryData {
  const _SummaryData({
    required this.session,
    required this.details,
    required this.previousVolume,
    required this.plan,
    required this.planChanged,
    required this.records,
    required this.supersets,
  });

  /// Supersets of the session (M9).
  final Map<int, SessionSuperset> supersets;

  /// New records of this session (SPEC §6.3).
  final List<SessionRecord> records;

  final Session session;
  final List<SessionExerciseDetail> details;
  final double? previousVolume;

  /// The plan of the session if it still exists.
  final Plan? plan;
  final bool planChanged;
}

final _summaryProvider = FutureProvider.autoDispose.family<_SummaryData?, int>((
  ref,
  sessionId,
) async {
  final sessions = ref.read(sessionRepositoryProvider);
  final plans = ref.read(planRepositoryProvider);
  final session = await sessions.findById(sessionId);
  if (session == null) return null;
  final details = await sessions.getDetails(sessionId);
  final previous = await sessions.previousPlanSessionDetails(session);
  final plan = session.planId == null
      ? null
      : await plans.findById(session.planId!);
  final supersets = await sessions.getSupersets(sessionId);
  final changed =
      plan != null &&
      await plans.sessionChangesPlan(plan.id, details, supersets);
  return _SummaryData(
    session: session,
    details: details,
    previousVolume: previous == null ? null : sessionVolume(previous),
    plan: plan,
    planChanged: changed,
    records: await sessions.sessionRecords(sessionId),
    supersets: supersets,
  );
});

/// Full-screen summary after finishing a session (SPEC §6.3).
class SummaryPage extends ConsumerStatefulWidget {
  const SummaryPage({required this.sessionId, super.key});

  final int sessionId;

  @override
  ConsumerState<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends ConsumerState<SummaryPage> {
  final _notes = TextEditingController();
  bool _notesLoaded = false;
  bool _adopt = false;
  String? _savedPlanName;
  bool _closing = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() => ref
      .read(sessionRepositoryProvider)
      .updateNotes(widget.sessionId, _notes.text);

  void _onNotesChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _saveNotes().catchError((Object e) {
        if (mounted) showError(context, e);
      });
    });
  }

  Future<void> _saveAsPlan(_SummaryData data) async {
    await showNameDialog(
      context,
      title: S.saveAsPlan,
      confirmLabel: S.save,
      onSubmit: (name) async {
        try {
          final planId = await ref
              .read(planRepositoryProvider)
              .createFromSession(name, data.details, data.supersets);
          await ref
              .read(settingsRepositoryProvider)
              .update((s) => s.copyWith(lastSelectedPlanId: planId));
          if (mounted) setState(() => _savedPlanName = name);
          return null;
        } on DuplicateNameException {
          return S.errorPlanNameTaken;
        } on Object {
          return S.errorUnexpected;
        }
      },
    );
  }

  /// "Fertig" (also system back): save notes, adopt into the plan if chosen.
  Future<void> _done(_SummaryData? data) async {
    if (_closing) return;
    _closing = true;
    _debounce?.cancel();
    try {
      if (data != null) {
        await _saveNotes();
        if (_adopt && data.plan != null) {
          await ref
              .read(planRepositoryProvider)
              .adoptSession(data.plan!.id, data.details, data.supersets);
        }
      }
    } on Object catch (e) {
      _closing = false;
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.training);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_summaryProvider(widget.sessionId));
    final data = async.value;
    if (data != null && !_notesLoaded) {
      _notes.text = data.session.notes;
      _notesLoaded = true;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done(data);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            data == null
                ? S.summaryTitle
                : data.session.planNameSnapshot ?? S.freeTrainingTitle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: data == null
            ? const SizedBox.shrink()
            : _SummaryBody(
                data: data,
                notes: _notes,
                onNotesChanged: _onNotesChanged,
                adopt: _adopt,
                onAdoptChanged: (v) => setState(() => _adopt = v),
                savedPlanName: _savedPlanName,
                onSaveAsPlan: () => _saveAsPlan(data),
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              onPressed: () => _done(data),
              child: const Text(S.finished),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.data,
    required this.notes,
    required this.onNotesChanged,
    required this.adopt,
    required this.onAdoptChanged,
    required this.savedPlanName,
    required this.onSaveAsPlan,
  });

  final _SummaryData data;
  final TextEditingController notes;
  final ValueChanged<String> onNotesChanged;
  final bool adopt;
  final ValueChanged<bool> onAdoptChanged;
  final String? savedPlanName;
  final VoidCallback onSaveAsPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final s = data.session;
    final trained = data.details.where((d) => d.sets.isNotEmpty);
    final sets = data.details.fold<int>(0, (n, d) => n + d.sets.length);
    final volume = sessionVolume(data.details);
    final change = percentChange(volume, data.previousVolume);
    final number = NumberFormat.decimalPattern(appLocale);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(S.summaryTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        _TileRow(
          children: [
            _StatTile(
              label: S.statDuration,
              value: formatTrainingDuration(s.endedAt!.difference(s.startedAt)),
            ),
            _StatTile(label: S.statExercises, value: '${trained.length}'),
          ],
        ),
        const SizedBox(height: 8),
        _TileRow(
          children: [
            _StatTile(label: S.statSets, value: '$sets'),
            _StatTile(
              label: S.statVolume,
              value: '${number.format(volume.round())} ${S.unitKg}',
              footer: change == null
                  ? null
                  : S.compareLast(
                      '${change >= 0 ? '+' : '−'}'
                      '${number.format(change.abs().round())} %',
                    ),
              footerColor: change == null
                  ? null
                  : change >= 0
                  ? gym.success
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        if (data.records.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(S.newRecords, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final r in data.records)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.emoji_events, color: gym.record),
              title: Text(r.exercise.name),
              subtitle: Text(
                '${S.recordKind(r.kind)}: ${formatRecordValue(r.kind, r.value)}',
              ),
            ),
        ],
        const SizedBox(height: 16),
        if (data.plan != null && data.planChanged)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(S.adoptIntoPlan(data.plan!.name)),
            value: adopt,
            onChanged: onAdoptChanged,
          ),
        if (s.isFreeTraining && trained.isNotEmpty)
          savedPlanName == null
              ? OutlinedButton.icon(
                  icon: const Icon(Icons.playlist_add),
                  label: const Text(S.saveAsPlan),
                  onPressed: onSaveAsPlan,
                )
              : Row(
                  children: [
                    Icon(Icons.check_circle, color: gym.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text(S.savedAsPlan(savedPlanName!))),
                  ],
                ),
        const _BackupHint(),
        const SizedBox(height: 16),
        TextField(
          controller: notes,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: S.fieldNotes,
            hintText: S.summaryNotesHint,
          ),
          onChanged: onNotesChanged,
        ),
      ],
    );
  }
}

/// Two tiles side by side with equal height (grows with the font size).
class _TileRow extends StatelessWidget {
  const _TileRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: 8),
        Expanded(child: children[1]),
      ],
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.footer,
    this.footerColor,
  });

  final String label;
  final String value;
  final String? footer;
  final Color? footerColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: NumberStyles.medium.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (footer != null)
              Text(
                footer!,
                style: theme.textTheme.bodySmall?.copyWith(color: footerColor),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Letztes Backup vor 21 Tagen" + "Backup erstellen" (SPEC §6.3).
class _BackupHint extends ConsumerWidget {
  const _BackupHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null || settings.backupReminderDays == 0) {
      return const SizedBox.shrink();
    }
    final last = settings.lastBackupAt;
    final days = last == null
        ? null
        : ref.watch(clockProvider).now().difference(last).inDays;
    if (days != null && days <= settings.backupReminderDays) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 16),
      color: gym.restContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.backup_outlined, color: gym.onRestContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    days == null ? S.noBackupYet : S.backupAgo(days),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: gym.onRestContainer,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: gym.onRestContainer,
                ),
                onPressed: () => createBackupFlow(context, ref),
                child: const Text(S.createBackup),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
