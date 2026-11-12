import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/device.dart';
import '../../core/heart_rate_monitor.dart';
import '../../data/providers.dart';
import '../../domain/heart_rate.dart';

enum HeartRateStatus {
  /// No training or no monitor chosen.
  off,

  /// Bluetooth off, permission missing or Android too old.
  unavailable,
  connecting,
  connected,

  /// The connection was lost; GymLog tries again.
  reconnecting,
}

/// What the training screen shows (1.5.0).
typedef HeartRateLive = ({HeartRateStatus status, int? bpm});

class HeartRateLiveNotifier extends Notifier<HeartRateLive> {
  @override
  HeartRateLive build() => (status: HeartRateStatus.off, bpm: null);

  void set(HeartRateStatus status, [int? bpm]) =>
      state = (status: status, bpm: bpm);
}

final heartRateLiveProvider =
    NotifierProvider<HeartRateLiveNotifier, HeartRateLive>(
      HeartRateLiveNotifier.new,
    );

/// Records the heart rate during a training (1.5.0): connects to the chosen
/// monitor while a training runs, reconnects after a loss and disconnects
/// when the training ends. Since 1.5.1 every value goes into the buffer,
/// written every [flushEvery]; the end of the training keeps only summaries.
/// Invisible; wraps the whole app.
class HeartRateRecorder extends ConsumerStatefulWidget {
  const HeartRateRecorder({required this.child, super.key});

  final Widget child;

  static const retryAfter = Duration(seconds: 5);
  static const flushEvery = Duration(seconds: 10);

  @override
  ConsumerState<HeartRateRecorder> createState() => _HeartRateRecorderState();
}

typedef _Target = ({int sessionId, String deviceId});

class _HeartRateRecorderState extends ConsumerState<HeartRateRecorder>
    with WidgetsBindingObserver {
  _Target? _target;
  StreamSubscription<HeartRateReading>? _readings;
  Timer? _retry;
  Timer? _flushTimer;
  final _pending = <({DateTime at, int bpm})>[];
  int? _pendingSession;
  DateTime? _lastWarning;

  /// At most one warning vibration in this time (1.6.0).
  static const warnEvery = Duration(minutes: 2);

  Clock get _clock => ref.read(clockProvider);
  HeartRateLiveNotifier get _live => ref.read(heartRateLiveProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retry?.cancel();
    _flushTimer?.cancel();
    unawaited(_readings?.cancel());
    super.dispose();
  }

  /// Writes the collected values (a few seconds' worth at most).
  void _flush() {
    final session = _pendingSession;
    if (_pending.isEmpty || session == null) return;
    final values = [..._pending];
    _pending.clear();
    unawaited(
      ref
          .read(heartRateRepositoryProvider)
          .addSamples(session, values)
          .catchError((Object e) {
            // The training was deleted in the meantime.
            debugPrint('Heart rate not stored: $e');
            return false;
          }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Bluetooth switched on or permission granted in the meantime.
    if (state == AppLifecycleState.resumed &&
        _target != null &&
        ref.read(heartRateLiveProvider).status == HeartRateStatus.unavailable) {
      unawaited(_connect());
    }
  }

  Future<void> _stop() async {
    _retry?.cancel();
    _retry = null;
    _flush();
    final readings = _readings;
    _readings = null;
    await readings?.cancel();
  }

  Future<void> _restart() async {
    await _stop();
    if (!mounted) return;
    if (_target == null) {
      _live.set(HeartRateStatus.off);
      return;
    }
    await _connect();
  }

  Future<void> _connect() async {
    final target = _target;
    if (target == null || !mounted) return;
    await _stop();
    _live.set(HeartRateStatus.connecting);
    final monitor = ref.read(heartRateMonitorProvider);
    if (await monitor.availability() != HeartRateAvailability.ready) {
      if (mounted && _target == target) _live.set(HeartRateStatus.unavailable);
      return;
    }
    if (!mounted || _target != target) return;
    _readings = monitor
        .heartRate(target.deviceId)
        .listen(
          (reading) => _onReading(target, reading.bpm),
          onError: (Object _) => _lost(target),
          onDone: () => _lost(target),
          cancelOnError: true,
        );
  }

  void _onReading(_Target target, int bpm) {
    if (!mounted || _target != target) return;
    _live.set(HeartRateStatus.connected, bpm);
    if (_pendingSession != target.sessionId) {
      _flush();
      _pendingSession = target.sessionId;
    }
    final now = _clock.now();
    _pending.add((at: now, bpm: bpm));
    _warnIfHigh(bpm, now);
    _flushTimer ??= Timer.periodic(HeartRateRecorder.flushEvery, (_) {
      if (mounted) _flush();
    });
  }

  /// Vibrates above the warning limit of the heart rate profile, at most
  /// every [warnEvery] (1.6.0). The display turns red by itself.
  void _warnIfHigh(int bpm, DateTime now) {
    final settings = ref.read(settingsProvider).value;
    final limit = settings?.hrWarnBpm;
    if (settings == null || limit == null || bpm < limit) return;
    final last = _lastWarning;
    if (last != null && now.difference(last) < warnEvery) return;
    _lastWarning = now;
    if (settings.vibrationEnabled) {
      unawaited(ref.read(deviceFeedbackProvider).heartRateWarning());
    }
  }

  void _lost(_Target target) {
    if (!mounted || _target != target) return;
    _readings = null;
    _live.set(HeartRateStatus.reconnecting);
    _retry?.cancel();
    _retry = Timer(HeartRateRecorder.retryAfter, () => unawaited(_connect()));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider).value;
    final device = ref.watch(settingsProvider).value?.hrDeviceId;
    final target = session != null && device != null
        ? (sessionId: session.id, deviceId: device)
        : null;
    if (target != _target) {
      _target = target;
      if (target == null) {
        _flushTimer?.cancel();
        _flushTimer = null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_restart());
      });
    }
    return widget.child;
  }
}
