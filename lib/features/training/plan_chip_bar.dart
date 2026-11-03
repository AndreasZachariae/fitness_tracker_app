import 'package:flutter/material.dart';

import '../../core/l10n/strings_de.dart';
import '../../domain/models/models.dart';

/// Horizontal plan chips: plans in order, "Frei", "+ Plan" (SPEC §6.1).
class PlanChipBar extends StatelessWidget {
  const PlanChipBar({
    required this.plans,
    required this.selectedPlanId,
    required this.onSelect,
    required this.onCreate,
    required this.onLongPress,
    super.key,
  });

  final List<Plan> plans;

  /// `null` = "Frei".
  final int? selectedPlanId;
  final ValueChanged<int?> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<Plan> onLongPress;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        spacing: 8,
        children: [
          for (final plan in plans)
            GestureDetector(
              onLongPress: () => onLongPress(plan),
              child: ChoiceChip(
                label: Text(plan.name),
                selected: plan.id == selectedPlanId,
                onSelected: (_) => onSelect(plan.id),
              ),
            ),
          ChoiceChip(
            label: const Text(S.freeTraining),
            selected: selectedPlanId == null,
            onSelected: (_) => onSelect(null),
          ),
          ActionChip(
            avatar: const Icon(Icons.add),
            label: const Text(S.addPlanChip),
            tooltip: S.newPlan,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}
