import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

/// Android channels of GymLog (1.2.0); the user can mute each one in the
/// system settings.
enum NotificationChannel {
  /// Training days, open training, backup, streak.
  reminders('reminders', 'Erinnerungen'),

  /// The rest countdown on the lock screen (silent).
  rest('rest', 'Pause'),

  /// New version on GitHub.
  updates('updates', 'Updates');

  const NotificationChannel(this.id, this.label);

  final String id;
  final String label;
}

/// A button of a notification.
typedef NotificationButton = ({String id, String label});

/// Called when a notification or one of its buttons is tapped.
typedef NotificationTap = void Function(String? payload, String? buttonId);

/// Notifications of the device (1.2.0). Failures are ignored everywhere:
/// a missing reminder must never look like an error.
abstract interface class NotificationGateway {
  Future<void> init(NotificationTap onTap);

  /// Asks for the Android 13+ permission; `true` if notifications show.
  Future<bool> requestPermission();

  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    NotificationChannel channel = NotificationChannel.reminders,
    String? payload,
    List<NotificationButton> buttons = const [],
  });

  Future<void> show({
    required int id,
    required String title,
    required String body,
    NotificationChannel channel = NotificationChannel.reminders,
    String? payload,
  });

  /// Silent, ongoing countdown to [end] that disappears shortly after.
  Future<void> showCountdown({
    required int id,
    required DateTime end,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);

  /// Ids of the notifications scheduled for later.
  Future<List<int>> scheduledIds();
}

final class PlatformNotifications implements NotificationGateway {
  PlatformNotifications();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _icon = 'ic_notification';

  static Future<T?> _safe<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      debugPrint('Notification failed: $e');
      return null;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init(NotificationTap onTap) => _safe(() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon),
      ),
      onDidReceiveNotificationResponse: (r) => onTap(r.payload, r.actionId),
    );
    // The app was started by tapping a notification.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
      onTap(response.payload, response.actionId);
    }
  });

  @override
  Future<bool> requestPermission() async =>
      await _safe(
        () async => await _android?.requestNotificationsPermission() ?? false,
      ) ??
      false;

  AndroidNotificationDetails _details(
    NotificationChannel channel, {
    List<NotificationButton> buttons = const [],
  }) => AndroidNotificationDetails(
    channel.id,
    channel.label,
    icon: _icon,
    importance: channel == NotificationChannel.rest
        ? Importance.low
        : Importance.high,
    priority: channel == NotificationChannel.rest
        ? Priority.low
        : Priority.high,
    actions: [
      for (final b in buttons)
        AndroidNotificationAction(b.id, b.label, showsUserInterface: true),
    ],
  );

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    NotificationChannel channel = NotificationChannel.reminders,
    String? payload,
    List<NotificationButton> buttons = const [],
  }) => _safe(() async {
    Future<void> run(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: id,
      // An absolute instant: no time zone database needed.
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: NotificationDetails(
        android: _details(channel, buttons: buttons),
      ),
      androidScheduleMode: mode,
      title: title,
      body: body,
      payload: payload,
    );
    try {
      await run(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      // Exact alarms revoked by the user: a little late is fine.
      await run(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  });

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    NotificationChannel channel = NotificationChannel.reminders,
    String? payload,
  }) => _safe(
    () => _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: _details(channel)),
      payload: payload,
    ),
  );

  @override
  Future<void> showCountdown({
    required int id,
    required DateTime end,
    required String title,
    required String body,
  }) => _safe(() {
    final remaining = end.difference(DateTime.now());
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannel.rest.id,
          NotificationChannel.rest.label,
          icon: _icon,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          showWhen: true,
          when: end.millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: true,
          // Gone a little after the end (the alarm vibrates then).
          timeoutAfter: remaining.inMilliseconds + 15000,
          category: AndroidNotificationCategory.stopwatch,
        ),
      ),
    );
  });

  @override
  Future<void> cancel(int id) => _safe(() => _plugin.cancel(id: id));

  @override
  Future<List<int>> scheduledIds() async =>
      await _safe(
        () async => [
          for (final r in await _plugin.pendingNotificationRequests()) r.id,
        ],
      ) ??
      const [];
}

final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => PlatformNotifications(),
);
