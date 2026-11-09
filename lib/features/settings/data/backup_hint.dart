import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../core/theme/gym_colors.dart';
import '../../../data/providers.dart';
import 'data_actions.dart';

/// "Letztes Backup vor 21 Tagen" + "Backup erstellen" (SPEC §6.3), shown in
/// Settings → Daten when the backup reminder is due (1.0.1; before on the
/// training summary). Nothing when a backup is recent or the reminder is off.
class BackupHint extends ConsumerWidget {
  const BackupHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    // Nothing to back up yet: no card (1.2.1, it is on the start page now).
    final trained = ref.watch(historyProvider).value?.isNotEmpty ?? false;
    if (settings == null || settings.backupReminderDays == 0 || !trained) {
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
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
