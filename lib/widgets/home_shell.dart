import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format/formatters.dart';
import '../core/l10n/strings_de.dart';
import '../core/theme/typography.dart';
import '../data/providers.dart';
import '../domain/models/models.dart';
import '../features/training/session/forgotten_session_guard.dart';
import '../features/training/session/keep_screen_on.dart';
import '../features/training/session/rest_timer_bar.dart';
import 'ticker.dart';

/// Scaffold with the bottom [NavigationBar] around the four tabs. While a
/// session runs, other tabs show a slim "Training läuft" bar and the
/// training icon carries a dot (SPEC §6).
class HomeShell extends ConsumerWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _trainingBranch = 0;

  void _goTo(int index) => navigationShell.goBranch(
    index,
    // Tapping the current tab again returns to its start page.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSessionProvider).value;
    final showBar =
        active != null && navigationShell.currentIndex != _trainingBranch;

    return ForgottenSessionGuard(
      child: KeepScreenOn(
        child: Scaffold(
          body: Column(
            children: [
              if (showBar)
                _RunningSessionBar(
                  session: active,
                  onTap: () => _goTo(_trainingBranch),
                ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: showBar,
                  child: navigationShell,
                ),
              ),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RestTimerBar(),
              NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _goTo,
                destinations: [
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: active != null,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.fitness_center_outlined),
                    ),
                    selectedIcon: const Icon(Icons.fitness_center),
                    label: S.tabTraining,
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history),
                    label: S.tabHistory,
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights),
                    label: S.tabStats,
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.monitor_weight_outlined),
                    selectedIcon: Icon(Icons.monitor_weight),
                    label: S.tabBody,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunningSessionBar extends StatelessWidget {
  const _RunningSessionBar({required this.session, required this.onTap});

  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            button: true,
            label: S.trainingRunningA11y,
            child: SizedBox(
              height: 40,
              child: Center(
                child: ClockTicker(
                  builder: (context, now) => Text(
                    S.trainingRunning(
                      formatElapsed(now.difference(session.startedAt)),
                    ),
                    style: NumberStyles.small.copyWith(
                      fontSize: 17,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
