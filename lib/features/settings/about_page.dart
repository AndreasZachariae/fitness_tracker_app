import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings_de.dart';
import '../../data/db/database.dart';
import '../../data/notifications/update_checker.dart';
import '../../data/providers.dart';
import '../../domain/reminders.dart';
import '../notifications/reminder_sync.dart';

/// Settings → Über (1.2.1): look for updates on demand, versions, licenses.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(appInfoProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text(S.sectionAbout)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const UpdateCheckTile(),
          const Divider(),
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
        ],
      ),
    );
  }
}

/// "Nach Updates suchen": tap to look now; a newer version offers the
/// release page, where the user reads what is new and decides (1.2.1).
class UpdateCheckTile extends ConsumerStatefulWidget {
  const UpdateCheckTile({super.key});

  @override
  ConsumerState<UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends ConsumerState<UpdateCheckTile> {
  bool _checking = false;
  UpdateResult? _result;

  Future<void> _check() async {
    setState(() => _checking = true);
    final result = await ref.read(updateCheckerProvider).checkNow();
    if (mounted) {
      setState(() {
        _checking = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(appInfoProvider).value;
    final known = ref.watch(settingsProvider).value?.latestVersion;
    // A newer version found earlier (also by the daily check) shows at once.
    final available = switch (_result) {
      UpdateAvailable(:final version) => version,
      _
          when known != null &&
              info != null &&
              isNewerVersion(known, info.version) =>
        known,
      _ => null,
    };
    final subtitle = _checking
        ? S.checkingUpdates
        : available != null
        ? S.updateAvailable(available)
        : switch (_result) {
            UpToDate(:final installed) => S.upToDate(installed),
            UpdateCheckFailed() => S.updateCheckFailed,
            _ => S.checkForUpdatesHint,
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: _checking
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Icon(
                  available != null
                      ? Icons.system_update_outlined
                      : Icons.update,
                ),
          title: const Text(S.checkForUpdates),
          subtitle: Text(subtitle),
          onTap: _checking ? null : _check,
        ),
        if (available != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.open_in_new),
                label: const Text(S.updateDownload),
                onPressed: () => openInBrowser(latestReleaseUrl),
              ),
            ),
          ),
      ],
    );
  }
}
