import 'package:flutter/material.dart';

import 'settings_action.dart';

/// Page frame of a tab: app bar with title and settings gear.
class TabPage extends StatelessWidget {
  const TabPage({required this.title, required this.body, super.key});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [SettingsAction()]),
      body: body,
    );
  }
}
