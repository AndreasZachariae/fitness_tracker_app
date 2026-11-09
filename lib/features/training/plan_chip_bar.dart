import 'package:flutter/material.dart';

import '../../core/l10n/strings_de.dart';
import '../../core/theme/gym_colors.dart';
import '../../domain/models/models.dart';

/// Horizontal plan chips: plans in order, "Frei", "+ Plan" (SPEC §6.1).
///
/// Only one chip can be selected, so there is no checkmark (it looked like a
/// multi-select filter and changed the chip width). The selected chip is
/// filled with the action color instead.
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
              child: _SelectChip(
                label: plan.name,
                selected: plan.id == selectedPlanId,
                inactive: !plan.active,
                onSelected: () => onSelect(plan.id),
              ),
            ),
          _SelectChip(
            label: S.freeTraining,
            selected: selectedPlanId == null,
            onSelected: () => onSelect(null),
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

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.inactive = false,
  });

  final String label;
  final bool selected;

  /// Plans not trained at the moment are greyed out (1.2.0), but stay
  /// selectable.
  final bool inactive;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final base = theme.chipTheme.labelStyle;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: gym.action,
      side: BorderSide(
        color: selected ? gym.action : theme.colorScheme.outlineVariant,
      ),
      backgroundColor: inactive && !selected
          ? theme.colorScheme.surfaceContainerHighest
          : null,
      labelStyle: base?.copyWith(
        color: selected
            ? gym.onAction
            : inactive
            ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
            : theme.colorScheme.onSurface,
      ),
      onSelected: (_) {
        if (!selected) onSelected();
      },
    );
  }
}
