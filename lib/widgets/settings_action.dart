import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/strings_de.dart';
import '../core/router.dart';

/// Gear button in the app bar of every tab; opens the settings.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: S.openSettings,
      onPressed: () => context.push(AppRoutes.settings),
    );
  }
}
