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

  /// Rest and set timer while GymLog is in the background (1.3.0; replaces
  /// the silent channel "rest" of 1.2.0, which Android hid on the lock
  /// screen). No sound; the end vibrates through the rest alarm.
  timer('timer', 'Pause und Zeit'),

  /// "Pause vorbei" / "Zeit um" at the end of a timer (1.3.0).
  timerDone('timer_done', 'Pause vorbei und Zeit um'),

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

  /// Ongoing timer without sound, also on the lock screen: counts down to
  /// [at] ([countDown]) or up from [at] (1.3.0).
  Future<void> showTimer({
    required int id,
    required DateTime at,
    required bool countDown,
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

  /// Channel of 1.2.0, replaced by [NotificationChannel.timer].
  static const _oldRestChannel = 'rest';

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
    // The importance of a channel cannot change; the old one goes (1.3.0).
    await _android?.deleteNotificationChannel(channelId: _oldRestChannel);
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
    importance: Importance.high,
    priority: Priority.high,
    // The end of a timer: visible on the lock screen, silent (the rest
    // alarm vibrates; GymLog plays no sounds).
    visibility: channel == NotificationChannel.timerDone
        ? NotificationVisibility.public
        : null,
    playSound: channel != NotificationChannel.timerDone,
    enableVibration: channel != NotificationChannel.timerDone,
    category: channel == NotificationChannel.timerDone
        ? AndroidNotificationCategory.alarm
        : null,
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
  Future<void> showTimer({
    required int id,
    required DateTime at,
    required bool countDown,
    required String title,
    required String body,
  }) => _safe(
    () => _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannel.timer.id,
          NotificationChannel.timer.label,
          icon: _icon,
          // "Default", not "low": Android hides silent notifications on the
          // lock screen – the reason the rest timer did not show (1.3.0).
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.public,
          ongoing: true,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          showWhen: true,
          when: at.millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: countDown,
          // A countdown makes room for "Pause vorbei" / "Zeit um".
          timeoutAfter: countDown
              ? at.difference(DateTime.now()).inMilliseconds.clamp(1, 1 << 31)
              : null,
          category: AndroidNotificationCategory.stopwatch,
        ),
      ),
    ),
  );

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
