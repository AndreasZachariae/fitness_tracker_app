import 'package:flutter/material.dart';

import '../../core/l10n/strings_de.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tab_page.dart';

/// Tab "Verlauf".
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      title: S.tabHistory,
      body: EmptyState(icon: Icons.history, message: S.historyEmpty),
    );
  }
}
