import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/build_info.dart';

import '../../core/l10n/strings_de.dart';
import '../../core/router.dart';
import '../../data/db/database.dart';
import '../../data/notifications/update_checker.dart';
import '../../data/providers.dart';
import '../../domain/updates.dart';
import 'release_notes_view.dart';

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
          const LatestNotesTile(),
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
/// update page, where the user reads what is new and decides (1.2.1, page
/// since 1.2.2).
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
                icon: const Icon(Icons.system_update),
                label: const Text(S.updateOpen),
                onPressed: () => context.push(AppRoutes.update),
              ),
            ),
          ),
      ],
    );
  }
}

/// The text of the newest release to fold open (1.2.2): what is new, in the
/// DEV app also the test list for the phone. Loads it when opened.
class LatestNotesTile extends ConsumerStatefulWidget {
  const LatestNotesTile({super.key});

  @override
  ConsumerState<LatestNotesTile> createState() => _LatestNotesTileState();
}

class _LatestNotesTileState extends ConsumerState<LatestNotesTile> {
  bool _loading = false;
  bool _failed = false;

  Future<void> _expanded(bool open) async {
    final checker = ref.read(updateCheckerProvider);
    if (!open || _loading) return;
    if (checker.latest != null) {
      // Found meanwhile by "Nach Updates suchen".
      setState(() => _failed = false);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    final result = await checker.checkNow();
    if (mounted) {
      setState(() {
        _loading = false;
        _failed = result is UpdateCheckFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = ref.read(updateCheckerProvider).latest;
    return ExpansionTile(
      leading: const Icon(Icons.article_outlined),
      title: const Text(
        isDevBuild ? S.releaseNotesLatestDev : S.releaseNotesLatest,
      ),
      subtitle: Text(release?.version ?? S.releaseNotesHint),
      shape: const Border(),
      onExpansionChanged: _expanded,
      childrenPadding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
      children: [
        if (_loading)
          const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        else if (release != null)
          ReleaseNotesView(markdown: release.notes)
        else if (_failed)
          const Text(S.updateCheckFailed),
      ],
    );
  }
}
