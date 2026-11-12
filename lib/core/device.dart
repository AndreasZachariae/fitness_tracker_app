import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Vibration. Failures are ignored everywhere: a missing vibration must
/// never look like an error (data is already stored). Since 1.3.1 GymLog
/// vibrates only at the end of a timer, not after "Satz speichern" or for a
/// record (decided by the user).
abstract interface class DeviceFeedback {
  /// End of the rest or of a countdown: 3 × 300 ms (SPEC §6.2.1).
  Future<void> restOver();

  /// Heart rate above the warning limit (1.6.0): two long buzzes.
  Future<void> heartRateWarning();
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

  /// Wait, buzz, pause, buzz, pause, buzz (ms) at full strength; 1.3.1:
  /// 3 × 300 ms (1.3.0: 500/500/800 was too much). Same as RestAlarm.kt.
  static const restOverPattern = [0, 300, 250, 300, 250, 300];
  static const restOverIntensities = [0, 255, 0, 255, 0, 255];

  /// Two long buzzes, clearly different from the end of a rest (1.6.0).
  static const warningPattern = [0, 700, 300, 700];
  static const warningIntensities = [0, 255, 0, 255];

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
  Future<void> heartRateWarning() => _buzz(
    () => Vibration.vibrate(
      pattern: warningPattern,
      intensities: warningIntensities,
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
