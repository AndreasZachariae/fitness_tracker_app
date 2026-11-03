import 'package:flutter/material.dart';

import '../../core/l10n/strings_de.dart';
import '../../widgets/empty_state.dart';

/// Settings, shown above the tab shell.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: const EmptyState(
        icon: Icons.settings_outlined,
        message: S.settingsEmpty,
      ),
    );
  }
}
