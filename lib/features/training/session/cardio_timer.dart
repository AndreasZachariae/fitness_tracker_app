import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/device.dart';
import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../domain/heart_rate_ranges.dart';
import '../../../domain/models/models.dart';
import '../../heart_rate/heart_rate_recorder.dart';
import '../../heart_rate/range_colors.dart';

/// The heart rate target of a warm-up / cardio exercise (1.6.0).
typedef HeartRateTarget = ({int? range, int? bpm, int minutes});

HeartRateTarget? heartRateTargetOf(Exercise e) => e.hasHeartRateTarget
    ? (range: e.hrTargetRange, bpm: e.hrTargetBpm, minutes: e.hrTargetMinutes!)
    : null;

/// "Bereich 2 (111–129 bpm)" or "mind. 120 bpm".
String heartRateTargetLabel(HeartRateTarget t, int? hrMax) {
  if (t.range case final r?) {
    if (hrMax == null) return S.hrRange(r);
    final range = garminRanges(hrMax)[r - 1];
    return '${S.hrRange(r)} (${S.hrRangeBpm(range.from, range.to)})';
  }
  return S.hrTargetAtLeast(t.bpm!);
}

/// Timer of a warm-up / cardio set (1.6.0): counts only the time in the
/// heart rate target – inside the range, or at least the bpm value. At
/// [HeartRateTarget.minutes] it vibrates, shows "Ziel erreicht" and hands
/// the whole duration to [onStopped]; "Stopp" before hands it over too.
class CardioTimer extends ConsumerStatefulWidget {
  const CardioTimer({
    required this.target,
    required this.onStopped,
    this.onStarted,
    super.key,
  });

  final HeartRateTarget target;
  final ValueChanged<int> onStopped;
  final VoidCallback? onStarted;

  static const tick = Duration(milliseconds: 500);

  @override
  ConsumerState<CardioTimer> createState() => _CardioTimerState();
}

class _CardioTimerState extends ConsumerState<CardioTimer> {
  DateTime? _startedAt;
  DateTime? _lastTick;
  double _inTarget = 0;
  Timer? _ticker;
  bool _reached = false;

  Clock get _clock => ref.read(clockProvider);
  int get _goal => widget.target.minutes * 60;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    final now = _clock.now();
    setState(() {
      _startedAt = now;
      _lastTick = now;
      _inTarget = 0;
      _reached = false;
    });
    _ticker = Timer.periodic(CardioTimer.tick, (_) => _onTick());
    widget.onStarted?.call();
  }

  void _onTick() {
    if (!mounted || _startedAt == null) return;
    final now = _clock.now();
    final delta = now.difference(_lastTick ?? now).inMilliseconds / 1000;
    _lastTick = now;
    final live = ref.read(heartRateLiveProvider);
    final hrMax = ref.read(settingsProvider).value?.hrMax;
    if (live.status == HeartRateStatus.connected &&
        live.bpm != null &&
        inTarget(
          live.bpm!,
          range: widget.target.range,
          targetBpm: widget.target.bpm,
          hrMax: hrMax,
        )) {
      // A gap (app paused) counts at most 5 s.
      _inTarget += delta.clamp(0, 5);
    }
    if (_inTarget >= _goal) {
      _reached = true;
      _stop();
      final settings = ref.read(settingsProvider).value;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if ((settings?.vibrationEnabled ?? true) &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
        unawaited(ref.read(deviceFeedbackProvider).restOver());
      }
      return;
    }
    setState(() {});
  }

  void _stop() {
    final start = _startedAt;
    if (start == null) return;
    _ticker?.cancel();
    _ticker = null;
    final seconds = _clock.now().difference(start).inSeconds;
    setState(() => _startedAt = null);
    widget.onStopped(seconds < 1 ? 1 : seconds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).value;
    final live = ref.watch(heartRateLiveProvider);
    final hrMax = settings?.hrMax;
    final label = heartRateTargetLabel(widget.target, hrMax);
    final running = _startedAt != null;
    final bpm = live.bpm;
    final inside =
        live.status == HeartRateStatus.connected &&
        bpm != null &&
        inTarget(
          bpm,
          range: widget.target.range,
          targetBpm: widget.target.bpm,
          hrMax: hrMax,
        );
    final goal = Duration(seconds: _goal);
    return Column(
      key: const ValueKey('cardio-timer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          S.cardioGoal(label, widget.target.minutes),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 96,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: running
                  ? theme.colorScheme.tertiaryContainer
                  : theme.colorScheme.secondaryContainer,
              foregroundColor: running
                  ? theme.colorScheme.onTertiaryContainer
                  : theme.colorScheme.onSecondaryContainer,
            ),
            onPressed: running ? _stop : _start,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(running ? Icons.stop : Icons.play_arrow, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    running
                        ? '${formatMinSec(Duration(seconds: _inTarget.floor()))}'
                              ' / ${formatMinSec(goal)}'
                        : S.stopwatchStart,
                    style: running
                        ? NumberStyles.display.copyWith(fontSize: 40)
                        : const TextStyle(fontSize: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (running)
          Row(
            children: [
              Icon(
                inside ? Icons.check_circle : Icons.favorite_border,
                size: 18,
                color: inside
                    ? (hrMax != null
                          ? rangeColor(rangeOf(bpm, hrMax))
                          : theme.colorScheme.primary)
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  inside ? S.cardioInTarget : S.cardioOutsideTarget,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          )
        else if (_reached)
          Text(
            S.cardioReached,
            key: const ValueKey('cardio-reached'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
      ],
    );
  }
}
