import 'dart:convert';
import 'dart:io';

import '../../core/clock.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/notifications.dart';
import '../../domain/reminders.dart';
import '../repositories/settings_repository.dart';
import 'reminder_service.dart';

/// Page of the newest release; opened in the browser to download the APK.
const latestReleaseUrl =
    'https://github.com/AndreasZachariae/fitness_tracker_app/releases/latest';

/// The newest release, e.g. `1.3.0` (without "v").
abstract interface class ReleaseSource {
  Future<String?> latestVersion();
}

/// One GET to the public GitHub API (1.2.0) – the only network access of
/// GymLog. No account, no data sent except what every HTTP request has.
final class GitHubReleases implements ReleaseSource {
  const GitHubReleases();

  static final _api = Uri.parse(
    'https://api.github.com/repos/AndreasZachariae/fitness_tracker_app/'
    'releases/latest',
  );

  @override
  Future<String?> latestVersion() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'GymLog';
    try {
      final request = await client.getUrl(_api);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final tag = (jsonDecode(body) as Map<String, Object?>)['tag_name'];
      return tag is String ? tag.replaceFirst(RegExp('^v'), '') : null;
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Looks for a newer release at most once a day (1.2.0). A newer version
/// is notified once and stays visible in the settings.
class UpdateChecker {
  UpdateChecker({
    required this.source,
    required this.settings,
    required this.gateway,
    required this.clock,
    required this.installedVersion,
  });

  final ReleaseSource source;
  final SettingsRepository settings;
  final NotificationGateway gateway;
  final Clock clock;
  final Future<String> Function() installedVersion;

  static const interval = Duration(hours: 24);

  Future<void> checkIfDue() async {
    final s = await settings.get();
    if (!s.checkUpdates) return;
    final now = clock.now();
    final last = s.lastUpdateCheckAt;
    if (last != null && now.difference(last) < interval) return;
    final latest = await source.latestVersion();
    if (latest == null) return; // Offline: try again next time.
    final installed = await installedVersion();
    final isNew = isNewerVersion(latest, installed);
    await settings.update(
      (x) => x.copyWith(
        lastUpdateCheckAt: now,
        latestVersion: isNew ? latest : null,
      ),
    );
    if (isNew && latest != s.latestVersion) {
      await gateway.show(
        id: ReminderIds.update,
        title: S.notifyUpdateTitle(latest),
        body: S.notifyUpdateBody,
        channel: NotificationChannel.updates,
        payload: NotificationPayloads.update,
      );
    }
  }
}
