import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/device.dart';
import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../../domain/reminders.dart';
import '../../../widgets/ticker.dart';
import 'background_timer.dart';

/// Without a duration a countdown starts at one minute (1.3.0).
const defaultCountdownSec = 60;

const TimerNotificationIds setTimerNotificationIds = (
  timer: ReminderIds.setTimer,
  done: ReminderIds.setTimerDone,
);

/// Large timer for timed exercises (SPEC §6.2): "Start" → running time →
/// "Stopp" hands the duration to [onStopped].
///
/// 1.3.0: the arrow next to it switches between counting up and a countdown
/// from [targetSec]. The countdown vibrates at zero and hands over the full
/// time; stopped early, the time done so far. In the background or with the
/// screen locked Android shows the timer and vibrates at the end.
class StopwatchButton extends ConsumerStatefulWidget {
  const StopwatchButton({
    required this.onStopped,
    this.countDown = false,
    this.targetSec,
    this.onToggleDirection,
    this.onStarted,
    this.label = '',
    super.key,
  });

  final ValueChanged<int> onStopped;

  /// Counts down from [targetSec] instead of up.
  final bool countDown;

  /// Start of the countdown; null = [defaultCountdownSec].
  final int? targetSec;

  /// The arrow; null hides it.
  final VoidCallback? onToggleDirection;

  /// Called on "Start" (ends a running rest).
  final VoidCallback? onStarted;

  /// Name of the exercise, for the lock screen.
  final String label;

  @override
  ConsumerState<StopwatchButton> createState() => _StopwatchButtonState();
}

class _StopwatchButtonState extends ConsumerState<StopwatchButton>
    with WidgetsBindingObserver {
  DateTime? _startedAt;

  /// Seconds of a running countdown (fixed at the start).
  int? _countFrom;
  Timer? _end;
  bool _handedOver = false;

  Clock get _clock => ref.read(clockProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _end?.cancel();
    if (_handedOver) unawaited(takeTimerBack(ref, setTimerNotificationIds));
    super.dispose();
  }

  bool get _running => _startedAt != null;

  int get _countdownSec => widget.targetSec ?? defaultCountdownSec;

  void _toggle() {
    final start = _startedAt;
    if (start == null) {
      final from = widget.countDown ? _countdownSec : null;
      setState(() {
        _startedAt = _clock.now();
        _countFrom = from;
      });
      if (from != null) {
        _end = Timer(Duration(seconds: from), _countdownOver);
      }
      widget.onStarted?.call();
      return;
    }
    var seconds = _clock.now().difference(start).inSeconds;
    if (_countFrom case final from?) seconds = seconds.clamp(0, from);
    _reset();
    widget.onStopped(seconds < 1 ? 1 : seconds);
  }

  void _reset() {
    _end?.cancel();
    _end = null;
    setState(() {
      _startedAt = null;
      _countFrom = null;
    });
  }

  void _countdownOver() {
    final from = _countFrom;
    if (!mounted || from == null) return;
    _reset();
    widget.onStopped(from);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final foreground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    final settings = ref.read(settingsProvider).value ?? AppSettings.defaults;
    // In the background the alarm vibrates.
    if (foreground && settings.vibrationEnabled) {
      unawaited(ref.read(deviceFeedbackProvider).restOver());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        final start = _startedAt;
        final settings = ref.read(settingsProvider).value;
        if (start == null || _handedOver || settings == null) return;
        _handedOver = true;
        final from = _countFrom;
        unawaited(
          handTimerToAndroid(
            ref,
            settings: settings,
            ids: setTimerNotificationIds,
            texts: (
              title: widget.label,
              body: S.notifySetTimerBody,
              doneTitle: S.notifySetTimerDoneTitle,
              doneBody: S.notifySetTimerDoneBody(widget.label),
            ),
            at: from == null ? start : start.add(Duration(seconds: from)),
            countDown: from != null,
          ),
        );
      case AppLifecycleState.resumed:
        if (!_handedOver) return;
        _handedOver = false;
        unawaited(takeTimerBack(ref, setTimerNotificationIds));
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = _startedAt;
    final countFrom = _countFrom;
    final button = SizedBox(
      height: 96,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          backgroundColor: _running
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.secondaryContainer,
          foregroundColor: _running
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onSecondaryContainer,
        ),
        onPressed: _toggle,
        child: start != null
            ? ClockTicker(
                interval: const Duration(milliseconds: 250),
                builder: (context, now) {
                  final elapsed = now.difference(start);
                  final shown = countFrom == null
                      ? elapsed
                      : Duration(seconds: countFrom) - elapsed;
                  // Over by the clock (the timer is the fallback when no
                  // frames are drawn, e.g. with the screen locked).
                  if (countFrom != null && shown <= Duration.zero) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _countdownOver(),
                    );
                  }
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stop, size: 32),
                        const SizedBox(width: 12),
                        Text(
                          formatMinSec(
                            // A countdown shows 0:01 until it is over.
                            countFrom == null
                                ? shown
                                : shown.isNegative
                                ? Duration.zero
                                : shown + const Duration(milliseconds: 999),
                          ),
                          style: NumberStyles.display.copyWith(fontSize: 48),
                        ),
                        const SizedBox(width: 12),
                        const Text(S.stopwatchStop),
                      ],
                    ),
                  );
                },
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, size: 32),
                    const SizedBox(width: 8),
                    const Text(
                      S.stopwatchStart,
                      style: TextStyle(fontSize: 22),
                    ),
                    if (widget.countDown) ...[
                      const SizedBox(width: 12),
                      Text(
                        formatMinSec(Duration(seconds: _countdownSec)),
                        style: NumberStyles.medium,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
    final toggle = widget.onToggleDirection;
    if (toggle == null) return button;
    return Row(
      children: [
        Expanded(child: button),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 96,
          child: IconButton.outlined(
            key: const ValueKey('timer-direction'),
            tooltip: widget.countDown ? S.timerCountsDown : S.timerCountsUp,
            // Fixed while the timer runs.
            onPressed: _running ? null : toggle,
            icon: Icon(
              widget.countDown ? Icons.arrow_downward : Icons.arrow_upward,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}
