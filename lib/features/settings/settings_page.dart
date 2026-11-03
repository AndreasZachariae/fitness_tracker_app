import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/build_info.dart';
import '../../core/format/exercise_format.dart';
import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/router.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/number_stepper.dart';
import '../../widgets/snackbars.dart';
import 'data/data_actions.dart';
import 'dev_tools_section.dart';

/// Settings, shown above the tab shell (SPEC §6.7).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.showDevTools = isDevBuild});

  /// Dev-only section; `false` in the release app.
  final bool showDevTools;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final sessionRunning = ref.watch(activeSessionProvider).value != null;
    final info = ref.watch(appInfoProvider).value;

    Future<void> update(AppSettings Function(AppSettings) change) async {
      try {
        await ref.read(settingsRepositoryProvider).update(change);
      } on Object catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: settings == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: const Text(S.settingsExercises),
                  subtitle: const Text(S.settingsExercisesSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.exercises),
                ),
                ListTile(
                  leading: const Icon(Icons.list_alt_outlined),
                  title: const Text(S.settingsPlans),
                  subtitle: const Text(S.settingsPlansSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.plans),
                ),
                const _Header(S.sectionTraining),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      NumberStepper(
                        label: S.settingDefaultSets,
                        valueText: '${settings.defaultSets}',
                        onDecrement: settings.defaultSets > 1
                            ? () => update(
                                (s) =>
                                    s.copyWith(defaultSets: s.defaultSets - 1),
                              )
                            : null,
                        onIncrement: settings.defaultSets < 10
                            ? () => update(
                                (s) =>
                                    s.copyWith(defaultSets: s.defaultSets + 1),
                              )
                            : null,
                      ),
                      NumberStepper(
                        label: S.settingDefaultRest,
                        valueText: formatDuration(settings.defaultRestSec),
                        onDecrement: settings.defaultRestSec >= 15
                            ? () => update(
                                (s) => s.copyWith(
                                  defaultRestSec: s.defaultRestSec - 15,
                                ),
                              )
                            : null,
                        onIncrement: settings.defaultRestSec <= 585
                            ? () => update(
                                (s) => s.copyWith(
                                  defaultRestSec: s.defaultRestSec + 15,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text(S.settingRestTimer),
                  value: settings.restTimerEnabled,
                  onChanged: (v) =>
                      update((s) => s.copyWith(restTimerEnabled: v)),
                ),
                SwitchListTile(
                  title: const Text(S.settingVibration),
                  value: settings.vibrationEnabled,
                  onChanged: (v) =>
                      update((s) => s.copyWith(vibrationEnabled: v)),
                ),
                SwitchListTile(
                  title: const Text(S.settingKeepScreenOn),
                  subtitle: const Text(S.settingKeepScreenOnSubtitle),
                  value: settings.keepScreenOn,
                  onChanged: (v) => update((s) => s.copyWith(keepScreenOn: v)),
                ),
                SwitchListTile(
                  title: const Text(S.settingAutoActivate),
                  value: settings.autoActivateNext,
                  onChanged: (v) =>
                      update((s) => s.copyWith(autoActivateNext: v)),
                ),
                const _Header(S.sectionAppearance),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<ThemePreference>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemePreference.system,
                        label: Text(S.themeSystem),
                      ),
                      ButtonSegment(
                        value: ThemePreference.light,
                        label: Text(S.themeLight),
                      ),
                      ButtonSegment(
                        value: ThemePreference.dark,
                        label: Text(S.themeDark),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (v) =>
                        update((s) => s.copyWith(themeMode: v.single)),
                  ),
                ),
                const _Header(S.sectionData),
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text(S.exportCsv),
                  subtitle: const Text(S.exportCsvSubtitle),
                  onTap: () => exportCsvFlow(context, ref),
                ),
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
                const _Header(S.sectionAbout),
                ListTile(
                  title: const Text(S.appVersion),
                  trailing: Text(info?.version ?? '–'),
                ),
                ListTile(
                  title: const Text(S.buildNumber),
                  trailing: Text(info?.buildNumber ?? '–'),
                ),
                const ListTile(
                  title: Text(S.schemaVersion),
                  trailing: Text('${AppDatabase.currentSchemaVersion}'),
                ),
                ListTile(
                  title: const Text(S.licenses),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: S.appName,
                    applicationVersion: info == null
                        ? null
                        : '${info.version}+${info.buildNumber}',
                  ),
                ),
                if (showDevTools) const DevToolsSection(),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
