import 'package:gymlog/core/device.dart';
import 'package:gymlog/core/notifications.dart';
import 'package:gymlog/data/notifications/update_checker.dart';

/// Records calls instead of vibrating.
final class FakeFeedback implements DeviceFeedback {
  final calls = <String>[];

  @override
  Future<void> restOver() async => calls.add('restOver');
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
