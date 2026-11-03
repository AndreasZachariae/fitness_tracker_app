import 'package:flutter/material.dart';

import '../../core/build_info.dart';
import '../../core/l10n/strings_de.dart';
import '../../widgets/empty_state.dart';
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
      body: showDevTools
          ? ListView(children: const [DevToolsSection()])
          : const EmptyState(
              icon: Icons.settings_outlined,
              message: S.settingsEmpty,
            ),
    );
  }
}
