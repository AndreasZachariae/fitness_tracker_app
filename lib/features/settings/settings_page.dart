import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/build_info.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/router.dart';
import 'dev_tools_section.dart';

/// Settings, shown above the tab shell.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.showDevTools = isDevBuild});

  /// Dev-only section; `false` in the release app.
  final bool showDevTools;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text(S.settingsExercises),
            subtitle: const Text(S.settingsExercisesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.exercises),
          ),
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text(S.settingsPlans),
            subtitle: const Text(S.settingsPlansSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.plans),
          ),
          if (showDevTools) const DevToolsSection(),
        ],
      ),
    );
  }
}
