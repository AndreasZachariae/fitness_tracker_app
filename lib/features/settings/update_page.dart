import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/build_info.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/notifications/update_checker.dart';
import '../../data/notifications/update_installer.dart';
import '../../data/providers.dart';
import '../notifications/reminder_sync.dart';
import 'release_notes_view.dart';

/// A new version (1.2.2): what is new (for the DEV app: the test list),
/// download and install directly, or open the release on GitHub. Opens on
/// its own once per version, from the notification and from Über.
class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key});

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  UpdateResult? _result;
  bool _downloading = false;
  double? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load(useKnown: true));
  }

  Future<void> _load({bool useKnown = false}) async {
    setState(() => _result = null);
    final checker = ref.read(updateCheckerProvider);
    final result =
        (useKnown ? await checker.lastResult() : null) ??
        await checker.checkNow();
    if (mounted) setState(() => _result = result);
  }

  Future<void> _install(ReleaseInfo release) async {
    final installer = ref.read(updateInstallerProvider);
    setState(() => _error = null);
    if (!await installer.canInstall()) {
      if (!mounted) return;
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(S.updatePermissionTitle),
          content: const Text(S.updatePermissionBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(S.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(S.updatePermissionOpen),
            ),
          ],
        ),
      );
      if (open ?? false) await installer.openInstallSettings();
      return;
    }
    setState(() {
      _downloading = true;
      _progress = null;
    });
    String? error;
    try {
      final path = await installer.download(
        release,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await installer.install(path);
    } on UpdateDownloadException {
      error = S.updateDownloadFailed;
    } on Object {
      error = S.updateInstallFailed;
    }
    if (mounted) {
      setState(() {
        _downloading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text(S.updateTitle)),
      body: switch (result) {
        null => const Center(child: CircularProgressIndicator()),
        UpdateCheckFailed() => _Message(
          text: S.updateCheckFailed,
          action: OutlinedButton(
            onPressed: _load,
            child: const Text(S.updateRetry),
          ),
        ),
        UpToDate(:final installed, :final release) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(S.upToDate(installed), style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _Notes(release: release, initiallyExpanded: true),
          ],
        ),
        UpdateAvailable(:final release) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              S.updateHeadline(
                isDevBuild ? 'DEV ${release.version}' : release.version,
              ),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              S.updateInstalled(
                ref.watch(appInfoProvider).value?.version ?? '–',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (release.apkUrl == null)
              const Text(S.updateNoApk)
            else if (_downloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(S.updateDownloading(_progress)),
            ] else
              FilledButton.icon(
                icon: const Icon(Icons.system_update),
                label: const Text(S.updateInstall),
                onPressed: () => _install(release),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text(S.updateOnGitHub),
              onPressed: () => openInBrowser(release.pageUrl),
            ),
            const SizedBox(height: 8),
            Text(
              S.updateInstallHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _Notes(release: release, initiallyExpanded: true),
          ],
        ),
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.action});

  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          action,
        ],
      ),
    ),
  );
}

/// The release text to fold open.
class _Notes extends StatelessWidget {
  const _Notes({required this.release, required this.initiallyExpanded});

  final ReleaseInfo release;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card.outlined(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      title: const Text(isDevBuild ? S.releaseNotesDev : S.releaseNotes),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [ReleaseNotesView(markdown: release.notes)],
    ),
  );
}
