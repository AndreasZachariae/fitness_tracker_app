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

  /// Wait, buzz, pause, buzz, pause, long buzz (ms); 1.3.0: much stronger
  /// than before (3 × 150 ms), at full strength. Same as RestAlarm.kt.
  static const restOverPattern = [0, 500, 250, 500, 250, 800];
  static const restOverIntensities = [0, 255, 0, 255, 0, 255];

  /// A short, clearly noticeable knock after "Satz speichern" (1.3.0).
  static const setSavedMs = 90;

  /// Two knocks for a record (1.3.0).
  static const recordPattern = [0, 150, 100, 350];
  static const recordIntensities = [0, 255, 0, 255];

  static Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Not available on this device.
    }
  }

  /// Vibrates with the motor at full strength; falls back to the system
  /// haptics where there is no vibrator.
  static Future<void> _buzz(
    Future<void> Function() vibrate,
    Future<void> Function() fallback,
  ) => _safe(() async {
    if (await Vibration.hasVibrator()) {
      await vibrate();
    } else {
      await fallback();
    }
  });

  @override
  Future<void> setSaved() => _buzz(
    () => Vibration.vibrate(duration: setSavedMs, amplitude: 255),
    HapticFeedback.heavyImpact,
  );

  @override
  Future<void> record() => _buzz(
    () => Vibration.vibrate(
      pattern: recordPattern,
      intensities: recordIntensities,
    ),
    HapticFeedback.heavyImpact,
  );

  @override
  Future<void> restOver() => _buzz(
    () => Vibration.vibrate(
      pattern: restOverPattern,
      intensities: restOverIntensities,
    ),
    HapticFeedback.heavyImpact,
  );
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
