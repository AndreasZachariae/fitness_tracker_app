import 'package:flutter/services.dart';

/// State of an update download (1.6.1).
enum ApkDownloadStatus { pending, running, paused, done, failed }

typedef ApkDownloadState = ({
  ApkDownloadStatus status,
  int received,

  /// Total size in bytes; `null` while unknown.
  int? total,

  /// File name in Download/GymLog, once known.
  String? file,
});

/// The update APK via Android's download manager (1.6.1): Android downloads
/// into Download/GymLog and notifies when done; the user taps the file and
/// Android installs it. GymLog never installs anything itself (no
/// REQUEST_INSTALL_PACKAGES, Play Protect, 1.2.2). Only one APK is kept:
/// earlier GymLog downloads are removed before a new one starts.
abstract interface class ApkDownloader {
  /// Starts the download of [url] (a GitHub release file) and returns its
  /// id; the same file still running or already there is not started again.
  Future<int> start(String url);

  /// Progress of download [id]; `null` if Android does not know it.
  Future<ApkDownloadState?> query(int id);

  /// Removes all GymLog APK downloads with their files.
  Future<void> removeAll();

  /// Opens Android's list of downloads.
  Future<void> openDownloads();
}

final class PlatformApkDownloader implements ApkDownloader {
  const PlatformApkDownloader();

  static const _channel = MethodChannel('de.gymlog.app/downloads');

  @override
  Future<int> start(String url) async =>
      (await _channel.invokeMethod<int>('start', {'url': url}))!;

  @override
  Future<ApkDownloadState?> query(int id) async {
    final map = await _channel.invokeMapMethod<String, Object?>('query', {
      'id': id,
    });
    if (map == null) return null;
    final total = map['total'] as int? ?? -1;
    return (
      status: ApkDownloadStatus.values.byName(map['status']! as String),
      received: map['received'] as int? ?? 0,
      total: total > 0 ? total : null,
      file: map['file'] as String?,
    );
  }

  @override
  Future<void> removeAll() => _channel.invokeMethod<void>('removeAll');

  @override
  Future<void> openDownloads() => _channel.invokeMethod<void>('openDownloads');
}
