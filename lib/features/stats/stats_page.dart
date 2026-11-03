import 'package:flutter/material.dart';

import '../../core/l10n/strings_de.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tab_page.dart';

/// Tab "Statistik".
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      title: S.tabStats,
      body: EmptyState(icon: Icons.insights, message: S.statsEmpty),
    );
  }
}
