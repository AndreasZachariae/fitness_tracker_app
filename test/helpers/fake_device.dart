import 'dart:async';

import 'package:gymlog/core/device.dart';
import 'package:gymlog/core/heart_rate_monitor.dart';
import 'package:gymlog/core/notifications.dart';
import 'package:gymlog/data/notifications/apk_downloader.dart';
import 'package:gymlog/data/notifications/update_checker.dart';
import 'package:gymlog/domain/heart_rate.dart';

/// Records calls instead of vibrating.
final class FakeFeedback implements DeviceFeedback {
  final calls = <String>[];

  @override
  Future<void> restOver() async => calls.add('restOver');

  @override
  Future<void> heartRateWarning() async => calls.add('heartRateWarning');
}

/// Records scheduled and cancelled rest alarms.
final class FakeRestAlarm implements RestAlarm {
  final calls = <String>[];
  DateTime? scheduledAt;

  @override
  Future<void> schedule(DateTime at) async {
    scheduledAt = at;
    calls.add('schedule');
  }

  @override
  Future<void> cancel() async {
    scheduledAt = null;
    calls.add('cancel');
  }
}

final class FakeScreenAwake implements ScreenAwake {
  final states = <bool>[];

  bool get on => states.isNotEmpty && states.last;

  @override
  Future<void> set(bool on) async => states.add(on);
}

/// A notification as the fake saw it.
typedef FakeNotification = ({
  int id,
  DateTime? at,
  String title,
  String body,
  String? payload,
  List<NotificationButton> buttons,
});

/// Records notifications instead of showing them (1.2.0).
final class FakeNotifications implements NotificationGateway {
  final scheduled = <int, FakeNotification>{};
  final shown = <FakeNotification>[];
  final cancelled = <int>[];
  NotificationTap? onTap;
  int permissionRequests = 0;

  @override
  Future<void> init(NotificationTap onTap) async => this.onTap = onTap;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    NotificationChannel channel = NotificationChannel.reminders,
    String? payload,
    List<NotificationButton> buttons = const [],
  }) async => scheduled[id] = (
    id: id,
    at: at,
    title: title,
    body: body,
    payload: payload,
    buttons: buttons,
  );

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    NotificationChannel channel = NotificationChannel.reminders,
    String? payload,
  }) async => shown.add((
    id: id,
    at: null,
    title: title,
    body: body,
    payload: payload,
    buttons: const [],
  ));

  @override
  Future<void> showTimer({
    required int id,
    required DateTime at,
    required bool countDown,
    required String title,
    required String body,
  }) async => shown.add((
    id: id,
    at: at,
    title: title,
    body: body,
    payload: countDown ? 'countDown' : 'countUp',
    buttons: const [],
  ));

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }

  @override
  Future<List<int>> scheduledIds() async => [...scheduled.keys];
}

/// A fixed answer of the GitHub releases (null = offline).
final class FakeReleases implements ReleaseSource {
  FakeReleases([this.version, this.notes = '### Neu\n- Etwas Neues']);

  String? version;
  String notes;
  String? apkUrl = 'https://example.org/gymlog.apk';
  int calls = 0;

  @override
  Future<ReleaseInfo?> latest() async {
    calls++;
    final v = version;
    return v == null
        ? null
        : ReleaseInfo(
            version: v,
            notes: notes,
            pageUrl: 'https://example.org/releases/$v',
            apkUrl: apkUrl,
            apkSize: 3,
          );
  }
}

/// Android's download manager under the test's control (1.6.1).
final class FakeApkDownloader implements ApkDownloader {
  final started = <String>[];
  int removed = 0;
  int opened = 0;
  bool fail = false;
  ApkDownloadState state = (
    status: ApkDownloadStatus.pending,
    received: 0,
    total: null,
    file: null,
  );

  @override
  Future<int> start(String url, String fileName) async {
    if (fail) throw StateError('no download');
    started.add('$url → $fileName');
    return started.length;
  }

  @override
  Future<ApkDownloadState?> query(int id) async => state;

  @override
  Future<void> removeAll() async => removed++;

  @override
  Future<void> openFolder() async => opened++;
}

/// A heart rate monitor under the test's control (1.5.0).
final class FakeHeartRateMonitor implements HeartRateMonitor {
  HeartRateAvailability state = HeartRateAvailability.ready;
  bool grantOnRequest = true;
  final devices = <HeartRateDevice>[];
  final connects = <String>[];
  int permissionRequests = 0;
  StreamController<HeartRateReading>? _current;

  /// Whether a heart rate stream is open (connected).
  bool get connected => _current != null && !_current!.isClosed;

  /// Sends a value on the open connection.
  void beat(int bpm, {bool rr = false}) => _current?.add((bpm: bpm, hasRr: rr));

  /// The connection drops.
  void lose() {
    _current?.addError(const HeartRateConnectionLost());
    unawaited(_current?.close());
    _current = null;
  }

  @override
  Future<HeartRateAvailability> availability() async => state;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (grantOnRequest) state = HeartRateAvailability.ready;
    return grantOnRequest;
  }

  @override
  Stream<HeartRateDevice> scan() => Stream.fromIterable(devices);

  @override
  Stream<HeartRateReading> heartRate(String deviceId) {
    connects.add(deviceId);
    late final StreamController<HeartRateReading> controller;
    controller = StreamController<HeartRateReading>(
      onCancel: () {
        if (_current == controller) _current = null;
      },
    );
    _current = controller;
    return controller.stream;
  }
}
