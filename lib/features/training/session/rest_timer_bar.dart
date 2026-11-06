import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/device.dart';
import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../core/theme/gym_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../../domain/rest_timer.dart';
import '../../../widgets/ticker.dart';

/// In-memory changes of the rest timer: ±15 s per set, skipped sets and
/// sets whose end was already signalled.
final class RestAdjustments {
  const RestAdjustments({
    this.adjustSec = const {},
    this.skipped = const {},
    this.signalled = const {},
  });

  final Map<int, int> adjustSec;
  final Set<int> skipped;
  final Set<int> signalled;
}

class RestTimerController extends Notifier<RestAdjustments> {
  @override
  RestAdjustments build() => const RestAdjustments();

  void adjust(int setId, int seconds) => state = RestAdjustments(
    adjustSec: {
      ...state.adjustSec,
      setId: (state.adjustSec[setId] ?? 0) + seconds,
    },
    skipped: state.skipped,
    signalled: state.signalled,
  );

  void skip(int setId) => state = RestAdjustments(
    adjustSec: state.adjustSec,
    skipped: {...state.skipped, setId},
    signalled: state.signalled,
  );

  void markSignalled(int setId) => state = RestAdjustments(
    adjustSec: state.adjustSec,
    skipped: state.skipped,
    signalled: {...state.signalled, setId},
  );

  /// Ends every rest after these sets, e.g. when the training is finished
  /// or discarded: no bar and no vibration any more (1.0.1).
  void skipAll(Iterable<int> setIds) => state = RestAdjustments(
    adjustSec: state.adjustSec,
    skipped: {...state.skipped, ...setIds},
    signalled: state.signalled,
  );
}

final restTimerProvider =
    NotifierProvider<RestTimerController, RestAdjustments>(
      RestTimerController.new,
    );

/// "Pause 1:12" above the navigation bar (SPEC §6.2.1). In the foreground
/// the app vibrates at the end itself; when it goes to the background
/// during a rest, a [RestAlarm] takes over (1.0.1). No notifications.
class RestTimerBar extends ConsumerStatefulWidget {
  const RestTimerBar({super.key});

  @override
  ConsumerState<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends ConsumerState<RestTimerBar>
    with WidgetsBindingObserver {
  /// Sets whose rest was seen running; only those vibrate at the end.
  final _seenRunning = <int>{};

  /// The rest shown as running in the last build.
  ({int setId, DateTime end})? _running;

  /// The rest a background alarm was set for.
  ({int setId, DateTime end})? _alarm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        final running = _running;
        final settings = ref.read(settingsProvider).value;
        final adjustments = ref.read(restTimerProvider);
        if (running == null ||
            _alarm == running ||
            settings == null ||
            !settings.vibrationEnabled ||
            !settings.restTimerEnabled ||
            adjustments.skipped.contains(running.setId) ||
            adjustments.signalled.contains(running.setId)) {
          return;
        }
        _alarm = running;
        unawaited(ref.read(restAlarmProvider).schedule(running.end));
      case AppLifecycleState.resumed:
        final alarm = _alarm;
        if (alarm == null) return;
        _alarm = null;
        unawaited(ref.read(restAlarmProvider).cancel());
        // The alarm has vibrated already; do not vibrate a second time.
        if (!ref.read(clockProvider).now().isBefore(alarm.end)) {
          ref.read(restTimerProvider.notifier).markSignalled(alarm.setId);
        }
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _signalIfDue(int setId, AppSettings settings) {
    final adjustments = ref.read(restTimerProvider);
    // Read, not watched: a covered home screen gets no updates (Riverpod
    // pauses it), but a finished training has skipped its rests (1.0.1).
    if (!_seenRunning.contains(setId) ||
        adjustments.signalled.contains(setId) ||
        adjustments.skipped.contains(setId)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(restTimerProvider.notifier).markSignalled(setId);
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final foreground =
          lifecycle == null || lifecycle == AppLifecycleState.resumed;
      if (settings.vibrationEnabled && foreground) {
        ref.read(deviceFeedbackProvider).restOver();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider).value;
    final settings = ref.watch(settingsProvider).value ?? AppSettings.defaults;
    if (session == null || !settings.restTimerEnabled) {
      _running = null;
      return const SizedBox.shrink();
    }
    final details =
        ref.watch(sessionDetailsProvider(session.id)).value ?? const [];
    final supersets =
        ref.watch(sessionSupersetsProvider(session.id)).value ?? const {};
    // In a superset only the end of a round starts a rest (M9).
    final last = restAfterLatestSet(
      details,
      supersets,
      defaultRestSec: settings.defaultRestSec,
    );
    final adjustments = ref.watch(restTimerProvider);
    if (last == null || adjustments.skipped.contains(last.set.id)) {
      _running = null;
      return const SizedBox.shrink();
    }
    final setId = last.set.id;

    return ClockTicker(
      interval: const Duration(milliseconds: 250),
      builder: (context, now) {
        final state = restState(
          lastSetAt: last.set.completedAt,
          durationSec: last.durationSec,
          adjustSec: adjustments.adjustSec[setId] ?? 0,
          now: now,
        );
        _running = switch (state) {
          RestRunning(:final remaining) => (
            setId: setId,
            end: now.add(remaining),
          ),
          _ => null,
        };
        switch (state) {
          case RestHidden():
            return const SizedBox.shrink();
          case RestRunning():
            _seenRunning.add(setId);
            return _RunningBar(
              state: state,
              onMinus: () =>
                  ref.read(restTimerProvider.notifier).adjust(setId, -15),
              onPlus: () =>
                  ref.read(restTimerProvider.notifier).adjust(setId, 15),
              onSkip: () => ref.read(restTimerProvider.notifier).skip(setId),
            );
          case RestOver():
            _signalIfDue(setId, settings);
            return _OverBar(
              onTap: () => ref.read(restTimerProvider.notifier).skip(setId),
            );
        }
      },
    );
  }
}

class _RunningBar extends StatelessWidget {
  const _RunningBar({
    required this.state,
    required this.onMinus,
    required this.onPlus,
    required this.onSkip,
  });

  final RestRunning state;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final gym = GymColors.of(context);
    final fg = gym.onRestContainer;
    final button = TextButton.styleFrom(
      foregroundColor: fg,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 10),
    );
    return Material(
      color: gym.restContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: state.progress,
            minHeight: 4,
            color: fg,
            backgroundColor: fg.withValues(alpha: 0.15),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  fit: FlexFit.tight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          S.rest,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: fg),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatMinSec(
                            state.remaining + const Duration(milliseconds: 999),
                          ),
                          style: NumberStyles.medium.copyWith(color: fg),
                        ),
                      ],
                    ),
                  ),
                ),
                Flexible(
                  flex: 5,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      children: [
                        TextButton(
                          style: button,
                          onPressed: onMinus,
                          child: const Text(S.restMinus),
                        ),
                        TextButton(
                          style: button,
                          onPressed: onPlus,
                          child: const Text(S.restPlus),
                        ),
                        TextButton(
                          style: button,
                          onPressed: onSkip,
                          child: const Text(S.restSkip),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverBar extends StatelessWidget {
  const _OverBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gym = GymColors.of(context);
    return Material(
      color: gym.successContainer,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: gym.onSuccessContainer),
              const SizedBox(width: 12),
              Text(
                S.restOver,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: gym.onSuccessContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
