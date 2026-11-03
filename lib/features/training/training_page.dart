import 'package:flutter/material.dart';

import '../../core/l10n/strings_de.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tab_page.dart';

/// Tab "Training".
class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      title: S.tabTraining,
      body: EmptyState(icon: Icons.fitness_center, message: S.trainingEmpty),
    );
  }
}
