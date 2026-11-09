import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device.dart';
import '../../../core/notifications.dart';
import '../../../domain/models/models.dart';

/// Ids of the two notifications of one timer.
typedef TimerNotificationIds = ({int timer, int done});

/// Texts of the two notifications of one timer.
typedef TimerTexts = ({
  String title,
  String body,
  String doneTitle,
  String doneBody,
});

/// Hands a running timer to Android while GymLog is in the background or
/// the screen is locked: the exact alarm vibrates at the end (1.0.1), the
/// timer shows on the lock screen and "Pause vorbei" / "Zeit um" appears at
/// the end (1.2.0, visible on the lock screen since 1.3.0).
///
/// A count-up timer ([countDown] false, [at] = start) only shows itself.
Future<void> handTimerToAndroid(
  WidgetRef ref, {
  required AppSettings settings,
  required TimerNotificationIds ids,
  required TimerTexts texts,
  required DateTime at,
  required bool countDown,
}) async {
  final notifications = ref.read(notificationGatewayProvider);
  if (countDown && settings.vibrationEnabled) {
    unawaited(ref.read(restAlarmProvider).schedule(at));
  }
  if (!settings.notifyRest) return;
  await notifications.showTimer(
    id: ids.timer,
    at: at,
    countDown: countDown,
    title: texts.title,
    body: texts.body,
  );
  if (countDown) {
    await notifications.schedule(
      id: ids.done,
      at: at,
      title: texts.doneTitle,
      body: texts.doneBody,
      channel: NotificationChannel.timerDone,
    );
  }
}

/// Back in the app: the app shows and signals the timer itself again.
Future<void> takeTimerBack(WidgetRef ref, TimerNotificationIds ids) async {
  final notifications = ref.read(notificationGatewayProvider);
  await ref.read(restAlarmProvider).cancel();
  await notifications.cancel(ids.timer);
  await notifications.cancel(ids.done);
}
