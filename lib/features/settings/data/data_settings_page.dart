import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../data/providers.dart';
import '../../../widgets/number_stepper.dart';
import '../../../widgets/settings_section.dart';
import 'backup_hint.dart';
import 'data_actions.dart';

/// Settings → Daten (1.2.1): backup, restore, export.
class DataSettingsPage extends ConsumerWidget {
  const DataSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final sessionRunning = ref.watch(activeSessionProvider).value != null;
    final update = settingsUpdater(context, ref);
    return Scaffold(
      appBar: AppBar(title: const Text(S.sectionData)),
      body: settings == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                const SettingsSectionHeader(S.sectionBackup, first: true),
                const BackupHint(),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text(S.createBackup),
                  subtitle: Text(
                    settings.lastBackupAt == null
                        ? S.noBackupYet
                        : S.lastBackup(formatDateTime(settings.lastBackupAt!)),
                  ),
                  onTap: () => createBackupFlow(context, ref),
                ),
                ListTile(
                  enabled: !sessionRunning,
                  leading: const Icon(Icons.settings_backup_restore),
                  title: const Text(S.restoreBackup),
                  subtitle: sessionRunning
                      ? const Text(S.restoreBlocked)
                      : null,
                  onTap: () => restoreBackupFlow(context, ref),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: NumberStepper(
                    plainLabel: true,
                    label: S.backupReminder,
                    valueText: settings.backupReminderDays == 0
                        ? S.backupReminderOff
                        : S.days(settings.backupReminderDays),
                    onDecrement: settings.backupReminderDays > 0
                        ? () => update(
                            (s) => s.copyWith(
                              backupReminderDays: s.backupReminderDays - 1,
                            ),
                          )
                        : null,
                    onIncrement: settings.backupReminderDays < 365
                        ? () => update(
                            (s) => s.copyWith(
                              backupReminderDays: s.backupReminderDays + 1,
                            ),
                          )
                        : null,
                  ),
                ),
                const SettingsSectionHeader(S.sectionExport),
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text(S.exportCsv),
                  subtitle: const Text(S.exportCsvSubtitle),
                  onTap: () => exportCsvFlow(context, ref),
                ),
              ],
            ),
    );
  }
}
