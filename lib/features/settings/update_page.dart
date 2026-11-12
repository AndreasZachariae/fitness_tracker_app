import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/build_info.dart';
import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/notifications/apk_downloader.dart';
import '../../data/notifications/update_checker.dart';
import '../../data/providers.dart';
import '../../domain/updates.dart';
import '../notifications/reminder_sync.dart';
import 'release_notes_view.dart';

/// A new version (1.2.2): what is new (for the DEV app: the test list), the
/// APK to download, or the release on GitHub. Opens from the notification
/// and from Über.
///
/// GymLog never installs anything itself: an app that installs APKs
/// (REQUEST_INSTALL_PACKAGES) is blocked by Play Protect as harmful. Since
/// 1.6.1 Android's download manager downloads into Download/GymLog with the
/// progress shown here (before: the browser); the user taps the file,
/// Android installs.
class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key});

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  UpdateResult? _result;

  /// The running or finished download (1.6.1).
  int? _downloadId;
  ApkDownloadState? _download;
  bool _downloadFailed = false;
  Timer? _poll;

  static const pollEvery = Duration(milliseconds: 500);

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _startDownload(String url, String version) async {
    final downloader = ref.read(apkDownloaderProvider);
    setState(() {
      _downloadFailed = false;
      _download = (
        status: ApkDownloadStatus.pending,
        received: 0,
        total: null,
        file: null,
        found: null,
      );
    });
    try {
      _downloadId = await downloader.start(url, apkFileName(version), version);
    } on Object catch (e) {
      debugPrint('APK download failed: $e');
      if (mounted) setState(() => _downloadFailed = true);
      return;
    }
    _poll?.cancel();
    _poll = Timer.periodic(pollEvery, (_) => _refresh());
    await _refresh();
  }

  Future<void> _refresh() async {
    final id = _downloadId;
    if (id == null || !mounted) return;
    ApkDownloadState? state;
    try {
      state = await ref.read(apkDownloaderProvider).query(id);
    } on Object catch (e) {
      debugPrint('APK download state: $e');
    }
    if (!mounted) return;
    final over =
        state == null ||
        state.status == ApkDownloadStatus.done ||
        state.status == ApkDownloadStatus.failed ||
        state.status == ApkDownloadStatus.stale;
    if (over) _poll?.cancel();
    setState(() {
      _download = state;
      _downloadFailed =
          state == null || state.status == ApkDownloadStatus.failed;
    });
  }

  /// After a stale file (1.6.2): look again on GitHub, then download anew.
  Future<void> _retryStale() async {
    setState(() {
      _download = null;
      _downloadId = null;
    });
    await _load();
  }

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
              _DownloadBox(
                state: _downloadFailed ? null : _download,
                failed: _downloadFailed,
                onStart: () =>
                    _startDownload(release.apkAssetUrl ?? apk, release.version),
                onRetryStale: _retryStale,
                onOpenFolder: () =>
                    ref.read(apkDownloaderProvider).openFolder(),
                onBrowser: () => openInBrowser(apk),
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

/// "APK herunterladen", then the progress, then where the file lies and how
/// to install it (1.6.1).
class _DownloadBox extends StatelessWidget {
  const _DownloadBox({
    required this.state,
    required this.failed,
    required this.onStart,
    required this.onRetryStale,
    required this.onOpenFolder,
    required this.onBrowser,
  });

  final ApkDownloadState? state;
  final bool failed;
  final VoidCallback onStart;
  final VoidCallback onRetryStale;
  final VoidCallback onOpenFolder;
  final VoidCallback onBrowser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = state;
    if (failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.updateDownloadFailed,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text(S.updateRetry),
            onPressed: onStart,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_browser),
            label: const Text(S.updateDownloadInBrowser),
            onPressed: onBrowser,
          ),
        ],
      );
    }
    if (s != null && s.status == ApkDownloadStatus.stale) {
      return Column(
        key: const ValueKey('update-stale'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.updateDownloadStale(s.found ?? '?'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text(S.updateRetry),
            onPressed: onRetryStale,
          ),
        ],
      );
    }
    if (s == null) {
      return FilledButton.icon(
        icon: const Icon(Icons.download),
        label: const Text(S.updateDownload),
        onPressed: onStart,
      );
    }
    if (s.status == ApkDownloadStatus.done) {
      return Column(
        key: const ValueKey('update-downloaded'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  S.updateDownloaded(s.file ?? ''),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(S.updateInstallHint, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text(S.updateOpenFolder),
            onPressed: onOpenFolder,
          ),
        ],
      );
    }
    final total = s.total;
    return Column(
      key: const ValueKey('update-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: total == null ? null : s.received / total,
        ),
        const SizedBox(height: 6),
        Text(
          total == null
              ? S.updateDownloading
              : S.updateProgress(
                  formatMegabytes(s.received),
                  formatMegabytes(total),
                ),
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
