import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

final restTimerProvider =
    NotifierProvider<RestTimerController, RestAdjustments>(
      RestTimerController.new,
    );

/// "Pause 1:12" above the navigation bar (SPEC §6.2.1). Only in the
/// foreground, no notifications.
class RestTimerBar extends ConsumerStatefulWidget {
  const RestTimerBar({super.key});

  @override
  ConsumerState<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends ConsumerState<RestTimerBar> {
  /// Sets whose rest was seen running; only those vibrate at the end.
  final _seenRunning = <int>{};

  void _signalIfDue(int setId, AppSettings settings) {
    final adjustments = ref.read(restTimerProvider);
    if (!_seenRunning.contains(setId) ||
        adjustments.signalled.contains(setId)) {
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
