import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format/exercise_format.dart';
import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/exercise_type_icon.dart';
import '../../widgets/settings_action.dart';
import '../../widgets/snackbars.dart';

/// TEMPORARY until M3: overview of the running session. M3 replaces this
/// with the full session screen (SPEC §6.2).
class ActiveSessionPlaceholder extends ConsumerWidget {
  const ActiveSessionPlaceholder({required this.session, super.key});

  final Session session;

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    List<SessionExerciseDetail> details,
  ) async {
    final repo = ref.read(sessionRepositoryProvider);
    try {
      if (details.every((d) => d.sets.isEmpty)) {
        final discard = await showConfirmDialog(
          context,
          title: S.discardNoSetsTitle,
          confirmLabel: S.discard,
          cancelLabel: S.keepTraining,
          destructive: true,
        );
        if (!discard) return;
        await repo.delete(session.id);
        if (context.mounted) showMessage(context, S.trainingDiscarded);
      } else {
        await repo.finish(session.id);
      }
    } on Object catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final details =
        ref.watch(sessionDetailsProvider(session.id)).value ?? const [];
    final started = DateFormat.Hm(appLocale)
        .format(session.startedAt.toLocal());

    return Scaffold(
      appBar: AppBar(
        title: Text(session.planNameSnapshot ?? S.freeTrainingTitle),
        actions: const [SettingsAction()],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  S.trainingRunningSince(started),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(S.sessionViewComingSoon),
                  ),
                ),
                const SizedBox(height: 8),
                for (final d in details)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ExerciseTypeIcon(d.exercise.type),
                    title: Text(d.exercise.name),
                    subtitle: Text(
                      formatTarget(
                        d.exercise.type,
                        sets: d.sessionExercise.targetSets,
                        reps: d.sessionExercise.targetReps,
                        durationSec: d.sessionExercise.targetDurationSec,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _finish(context, ref, details),
                child: const Text(S.finishTraining),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
