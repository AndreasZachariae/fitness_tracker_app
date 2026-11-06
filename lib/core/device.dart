import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Haptics and vibration. Failures are ignored everywhere: a missing
/// vibration must never look like an error (data is already stored).
abstract interface class DeviceFeedback {
  /// After "Satz speichern".
  Future<void> setSaved();

  /// On a new record.
  Future<void> record();

  /// End of the rest: 3 × short (SPEC §6.2.1).
  Future<void> restOver();
}

/// Vibrates at the end of a rest while the app is in the background or the
/// screen is locked (1.0.1): an exact Android alarm, no notification.
abstract interface class RestAlarm {
  /// Vibrates at [at] unless [cancel] is called before. Replaces an earlier
  /// alarm.
  Future<void> schedule(DateTime at);

  Future<void> cancel();
}

/// Keeps the display on while a session runs (SPEC §6.2).
abstract interface class ScreenAwake {
  Future<void> set(bool on);
}

final class PlatformFeedback implements DeviceFeedback {
  const PlatformFeedback();

  /// Wait, buzz, pause, buzz, pause, buzz (ms).
  static const restOverPattern = [0, 150, 120, 150, 120, 150];

  static Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Not available on this device.
    }
  }

  @override
  Future<void> setSaved() => _safe(HapticFeedback.lightImpact);

  @override
  Future<void> record() => _safe(HapticFeedback.mediumImpact);

  @override
  Future<void> restOver() => _safe(() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(pattern: restOverPattern);
    }
  });
}

final class PlatformRestAlarm implements RestAlarm {
  const PlatformRestAlarm();

  /// Implemented in android/app/src/main/kotlin/de/gymlog/app/RestAlarm.kt.
  static const _channel = MethodChannel('de.gymlog.app/rest_alarm');

  @override
  Future<void> schedule(DateTime at) => PlatformFeedback._safe(
    () => _channel.invokeMethod<void>('schedule', {
      'atMillis': at.millisecondsSinceEpoch,
    }),
  );

  @override
  Future<void> cancel() =>
      PlatformFeedback._safe(() => _channel.invokeMethod<void>('cancel'));
}

final class PlatformScreenAwake implements ScreenAwake {
  const PlatformScreenAwake();

  @override
  Future<void> set(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } on Object {
      // Not available.
    }
  }
}

final deviceFeedbackProvider = Provider<DeviceFeedback>(
  (ref) => const PlatformFeedback(),
);

final restAlarmProvider = Provider<RestAlarm>(
  (ref) => const PlatformRestAlarm(),
);

final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => const PlatformScreenAwake(),
);
