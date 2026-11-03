import 'package:flutter/material.dart';

import '../../core/l10n/strings_de.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tab_page.dart';

/// Tab "Körper".
class BodyPage extends StatelessWidget {
  const BodyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      title: S.tabBody,
      body: EmptyState(icon: Icons.monitor_weight, message: S.bodyEmpty),
    );
  }
}
