import 'dart:convert';
import 'dart:io';

import '../../core/clock.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/notifications.dart';
import '../../domain/reminders.dart';
import '../../domain/updates.dart';
import '../repositories/settings_repository.dart';
import 'reminder_service.dart';

const _repo = 'AndreasZachariae/fitness_tracker_app';

/// Page of the newest release; fallback when GitHub sent no address.
const latestReleaseUrl = 'https://github.com/$_repo/releases/latest';

/// A release on GitHub as the app needs it (1.2.2).
final class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    this.apkUrl,
    this.apkSize,
  });

  /// `1.3.0` (release app) or `1.2.2-dev.31` (DEV app).
  final String version;

  /// Markdown text of the release: news, for DEV also the test list.
  final String notes;

  /// The release page on GitHub.
  final String pageUrl;

  /// Download of the APK; null if the release has none (yet).
  final String? apkUrl;

  /// Size of the APK in bytes, to check the download.
  final int? apkSize;
}

/// The newest release of the channel of this app.
abstract interface class ReleaseSource {
  /// Null when offline or GitHub does not answer.
  Future<ReleaseInfo?> latest();
}

/// One GET to the public GitHub API, without account or token. The release
/// app reads the newest release, the DEV app the pre-release "dev" (1.2.2).
///
/// Asks with the ETag of the last answer: "unchanged" (304) does not count
/// against GitHub's limit of 60 requests per hour, so GymLog can look on
/// every opening.
final class GitHubReleases implements ReleaseSource {
  GitHubReleases({required this.dev, this.endpoint});

  final bool dev;

  /// Only for tests (a local server); otherwise GitHub.
  final Uri? endpoint;
  String? _etag;
  ReleaseInfo? _cached;

  static final _latest = Uri.parse(
    'https://api.github.com/repos/$_repo/releases/latest',
  );
  static final _dev = Uri.parse(
    'https://api.github.com/repos/$_repo/releases/tags/dev',
  );

  @override
  Future<ReleaseInfo?> latest() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'GymLog';
    try {
      final request = await client.getUrl(endpoint ?? (dev ? _dev : _latest));
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      final etag = _etag;
      if (etag != null && _cached != null) {
        request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 304) {
        await response.drain<void>();
        return _cached;
      }
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      final release = parse(jsonDecode(body), dev: dev);
      _cached = release;
      _etag = release == null
          ? null
          : response.headers.value(HttpHeaders.etagHeader);
      return release;
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// The answer of the GitHub API; null if it is not a usable release.
  static ReleaseInfo? parse(Object? json, {required bool dev}) {
    if (json is! Map<String, Object?>) return null;
    final tag = json['tag_name'];
    final name = json['name'];
    final version = dev
        ? devVersionIn(name is String ? name : '')
        : tag is String
        ? tag.replaceFirst(RegExp('^v'), '')
        : null;
    if (version == null) return null;
    final assets = json['assets'];
    Map<String, Object?>? apk;
    if (assets is List) {
      for (final a in assets) {
        if (a is Map<String, Object?> &&
            a['name'] is String &&
            (a['name']! as String).endsWith('.apk') &&
            a['browser_download_url'] is String) {
          apk = a;
          break;
        }
      }
    }
    final page = json['html_url'];
    final notes = json['body'];
    return ReleaseInfo(
      version: version,
      notes: notes is String ? notes : '',
      pageUrl: page is String ? page : latestReleaseUrl,
      apkUrl: apk?['browser_download_url'] as String?,
      apkSize: apk?['size'] is int ? apk!['size']! as int : null,
    );
  }
}

/// Looks for a newer release whenever the app is opened (1.2.2): on every
/// start, on returning at most once a minute. A newer version is notified
/// once and stays visible in the settings (dot on the gear and on "Über").
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

  /// Shortest time between two automatic looks when returning to the app.
  static const interval = Duration(minutes: 1);

  /// The newest release of the last successful look (in memory only).
  ReleaseInfo? get latest => _latest;
  ReleaseInfo? _latest;

  /// The automatic check on opening the app ([force] on a fresh start,
  /// otherwise at most every [interval]). Returns the release when it is new
  /// to the app (notified now, shown once); otherwise null.
  Future<ReleaseInfo?> checkIfDue({bool force = false}) async {
    final s = await settings.get();
    if (!s.checkUpdates) return null;
    final last = s.lastUpdateCheckAt;
    if (!force &&
        last != null &&
        clock.now().difference(last).abs() < interval) {
      return null;
    }
    final result = await checkNow();
    if (result case UpdateAvailable(:final release)
        when release.version != s.latestVersion) {
      await gateway.show(
        id: ReminderIds.update,
        title: S.notifyUpdateTitle(release.version),
        body: S.notifyUpdateBody,
        channel: NotificationChannel.updates,
        payload: NotificationPayloads.update,
      );
      return release;
    }
    return null;
  }

  /// The result of the last successful look, without going online; null if
  /// there was none since the app started.
  Future<UpdateResult?> lastResult() async {
    final release = _latest;
    if (release == null) return null;
    final installed = await installedVersion();
    return isNewerVersion(release.version, installed)
        ? UpdateAvailable(release)
        : UpToDate(installed, release);
  }

  /// Looks right now (Settings → Über, update page), without notification.
  Future<UpdateResult> checkNow() async {
    final release = await source.latest();
    if (release == null) return const UpdateCheckFailed();
    _latest = release;
    final installed = await installedVersion();
    final isNew = isNewerVersion(release.version, installed);
    await settings.update(
      (x) => x.copyWith(
        lastUpdateCheckAt: clock.now(),
        latestVersion: isNew ? release.version : null,
      ),
    );
    return isNew ? UpdateAvailable(release) : UpToDate(installed, release);
  }
}

sealed class UpdateResult {
  const UpdateResult();
}

final class UpdateAvailable extends UpdateResult {
  const UpdateAvailable(this.release);

  final ReleaseInfo release;

  String get version => release.version;
}

final class UpToDate extends UpdateResult {
  const UpToDate(this.installed, this.release);

  final String installed;

  /// The newest release (its notes describe the installed version).
  final ReleaseInfo release;
}

/// Offline or GitHub not reachable.
final class UpdateCheckFailed extends UpdateResult {
  const UpdateCheckFailed();
}
