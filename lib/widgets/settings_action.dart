import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/strings_de.dart';
import '../core/router.dart';
import '../data/providers.dart';

/// Gear button in the app bar of every tab; opens the settings. A blue dot
/// shows a known update (1.2.2).
class SettingsAction extends ConsumerWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(knownUpdateProvider) != null;
    return IconButton(
      icon: Badge(
        key: const ValueKey('settings-update-dot'),
        isLabelVisible: update,
        smallSize: 10,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.settings_outlined),
      ),
      tooltip: S.openSettings,
      onPressed: () => context.push(AppRoutes.settings),
    );
  }
}
