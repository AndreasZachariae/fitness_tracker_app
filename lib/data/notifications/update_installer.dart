import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'update_checker.dart';

/// "Herunterladen und installieren" (1.2.2): loads the APK of a release and
/// hands it to the Android installer. Android asks before installing and only
/// accepts an APK signed with the key of the installed app – an update never
/// replaces GymLog by something else and never deletes its data.
abstract interface class UpdateInstaller {
  /// Whether GymLog may install apps ("Unbekannte Apps installieren").
  Future<bool> canInstall();

  /// Opens the Android page to allow it.
  Future<void> openInstallSettings();

  /// Loads the APK of [release]; [onProgress] gets 0…1 (null if unknown).
  /// Returns the file; throws [UpdateDownloadException] on failure.
  Future<String> download(
    ReleaseInfo release, {
    void Function(double? progress)? onProgress,
  });

  /// Starts the Android installer for the downloaded [path].
  Future<void> install(String path);
}

final class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.message);

  final String message;

  @override
  String toString() => 'UpdateDownloadException: $message';
}

final class PlatformUpdateInstaller implements UpdateInstaller {
  const PlatformUpdateInstaller();

  /// Implemented in android/app/src/main/kotlin/de/gymlog/app/UpdateInstaller.kt.
  static const _channel = MethodChannel('de.gymlog.app/updates');

  @override
  Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on Object {
      // Not available.
    }
  }

  @override
  Future<String> download(
    ReleaseInfo release, {
    void Function(double? progress)? onProgress,
  }) async {
    final url = release.apkUrl;
    if (url == null) throw const UpdateDownloadException('no APK');
    // Shared with the installer through the FileProvider (res/xml/update_paths.xml).
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final file = File('${dir.path}/gymlog-update.apk');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'GymLog';
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        throw UpdateDownloadException('HTTP ${response.statusCode}');
      }
      final total = response.contentLength > 0
          ? response.contentLength
          : release.apkSize;
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.timeout(
          const Duration(seconds: 30),
        )) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(total == null ? null : received / total);
        }
      } finally {
        await sink.close();
      }
      final expected = release.apkSize ?? total;
      if (expected != null && received != expected) {
        throw UpdateDownloadException('incomplete: $received of $expected');
      }
      return file.path;
    } on UpdateDownloadException {
      rethrow;
    } on Object catch (e) {
      throw UpdateDownloadException('$e');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> install(String path) =>
      _channel.invokeMethod<void>('install', {'path': path});
}
