import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/build_info.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/notifications/update_checker.dart';
import '../../data/providers.dart';
import '../notifications/reminder_sync.dart';
import 'release_notes_view.dart';

/// A new version (1.2.2): what is new (for the DEV app: the test list), the
/// APK to download in the browser, or the release on GitHub. Opens on its
/// own once per version, from the notification and from Über.
///
/// GymLog never installs anything itself: an app that downloads and installs
/// APKs (REQUEST_INSTALL_PACKAGES) is blocked by Play Protect as harmful. The
/// browser downloads, the user taps the file, Android installs.
class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key});

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  UpdateResult? _result;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text(S.updateTitle)),
      body: switch (_result) {
        null => const Center(child: CircularProgressIndicator()),
        UpdateCheckFailed() => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(S.updateCheckFailed, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _load,
                  child: const Text(S.updateRetry),
                ),
              ],
            ),
          ),
        ),
        UpToDate(:final installed, :final release) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(S.upToDate(installed), style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _Notes(release: release),
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
              style: muted,
            ),
            const SizedBox(height: 20),
            if (release.apkUrl case final apk?)
              FilledButton.icon(
                icon: const Icon(Icons.download),
                label: const Text(S.updateDownload),
                onPressed: () => openInBrowser(apk),
              )
            else
              const Text(S.updateNoApk),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text(S.updateOnGitHub),
              onPressed: () => openInBrowser(release.pageUrl),
            ),
            const SizedBox(height: 8),
            Text(S.updateDownloadHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            _Notes(release: release),
          ],
        ),
      },
    );
  }
}

/// The release text to fold open (open at first).
class _Notes extends StatelessWidget {
  const _Notes({required this.release});

  final ReleaseInfo release;

  @override
  Widget build(BuildContext context) => Card.outlined(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      initiallyExpanded: true,
      shape: const Border(),
      title: const Text(isDevBuild ? S.releaseNotesDev : S.releaseNotes),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [ReleaseNotesView(markdown: release.notes)],
    ),
  );
}
