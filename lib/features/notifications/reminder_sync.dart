import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/notifications.dart';
import '../../core/router.dart';
import '../../data/notifications/reminder_service.dart';
import '../../data/notifications/update_checker.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';

/// Off in most widget tests: they mix real file I/O with fake time, and
/// the background database work of the sync would interleave with it.
final reminderSyncEnabledProvider = Provider<bool>((ref) => true);

/// Keeps the planned notifications in line with the data (1.2.0): plans
/// them again after every relevant change and on every return to the app,
/// asks once for the permission, looks for updates on every opening (1.2.2)
/// and handles taps on notifications. Invisible; wraps the whole app.
class ReminderSync extends ConsumerStatefulWidget {
  const ReminderSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReminderSync> createState() => _ReminderSyncState();
}

class _ReminderSyncState extends ConsumerState<ReminderSync>
    with WidgetsBindingObserver {
  Timer? _debounce;
  bool _syncing = false;
  bool _again = false;

  late final bool _enabled = ref.read(reminderSyncEnabledProvider);

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _start() async {
    await ref.read(notificationGatewayProvider).init(_onTap);
    await _askPermissionOnce();
    await _sync();
    await _checkUpdates(appStarted: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_sync());
      unawaited(_checkUpdates());
    }
  }

  Future<void> _askPermissionOnce() async {
    try {
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final s = await settingsRepo.get();
      if (s.notificationsAsked || !_anyReminder(s)) return;
      await ref.read(notificationGatewayProvider).requestPermission();
      await settingsRepo.update((x) => x.copyWith(notificationsAsked: true));
    } on Object {
      // Not available; reminders simply do not show.
    }
  }

  static bool _anyReminder(AppSettings s) =>
      s.notifyEvening ||
      s.notifyBefore ||
      s.notifyRest ||
      s.notifyOpenSession ||
      s.notifyBackup ||
      s.notifyStreak ||
      s.checkUpdates;

  /// Several changes in a row lead to one sync.
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _sync);
  }

  Future<void> _sync() async {
    if (!mounted) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      await ref.read(reminderServiceProvider).sync();
    } on Object catch (e) {
      debugPrint('Reminder sync failed: $e');
    } finally {
      _syncing = false;
    }
    if (_again && mounted) {
      _again = false;
      await _sync();
    }
  }

  Future<void> _checkUpdates({bool appStarted = false}) async {
    if (!mounted) return;
    try {
      // A new version: notification and the blue dot on the gear; the
      // user opens the update page when it suits (1.3.1, before the page
      // opened by itself).
      final checker = ref.read(updateCheckerProvider);
      await checker.checkIfDue(force: appStarted);
      // Installed: the downloaded APK is not needed any more (1.6.1).
      if (appStarted && await checker.lastResult() is UpToDate && mounted) {
        await ref.read(apkDownloaderProvider).removeAll();
      }
    } on Object catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  Future<void> _onTap(String? payload, String? button) async {
    if (!mounted) return;
    if (button == NotificationPayloads.bookButton) {
      final url = (await ref.read(settingsRepositoryProvider).get()).bookingUrl;
      await openInBrowser(url);
      return;
    }
    switch (payload) {
      case NotificationPayloads.update:
        _openUpdatePage();
      case NotificationPayloads.backup:
        unawaited(ref.read(routerProvider).push(AppRoutes.settings));
      default:
        // The app opens; a running training shows itself.
        break;
    }
  }

  void _openUpdatePage() {
    final router = ref.read(routerProvider);
    if (router.state.matchedLocation == AppRoutes.update) return;
    unawaited(router.push(AppRoutes.update));
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    // Everything the reminders depend on.
    ref
      ..listen(settingsProvider, (_, _) => _schedule())
      ..listen(plansProvider, (_, _) => _schedule())
      ..listen(planSchedulesProvider, (_, _) => _schedule())
      ..listen(activeSessionProvider, (_, _) => _schedule())
      ..listen(historyProvider, (_, _) => _schedule())
      ..listen(lastPerformancesProvider, (_, _) => _schedule());
    final active = ref.watch(activeSessionProvider).value;
    if (active != null) {
      // A new set moves the "still open" reminder.
      ref.listen(sessionDetailsProvider(active.id), (_, _) => _schedule());
    }
    return widget.child;
  }
}

/// Opens [url] in the browser; GymLog itself does not go online for it.
Future<void> openInBrowser(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object catch (e) {
    debugPrint('Opening $url failed: $e');
  }
}
