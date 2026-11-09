import 'package:flutter/material.dart';

import '../core/l10n/strings_de.dart';
import '../core/theme/typography.dart';

/// `[−] value [+]` with 48 dp buttons. The caller owns the value; pass
/// `null` callbacks to disable a direction at its limit.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    required this.label,
    required this.valueText,
    required this.onDecrement,
    required this.onIncrement,
    this.helper,
    this.belowValue,
    this.plainLabel = false,
    super.key,
  });

  final String label;
  final String valueText;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  /// Small text below the label, e.g. "Standard (90 s)".
  final String? helper;

  /// Centered right below `[−] value [+]`, e.g. a unit switch (1.1.0).
  final Widget? belowValue;

  /// Label like a list entry (not bold), for settings pages next to
  /// switches (1.2.1).
  final bool plainLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: plainLabel
                      ? theme.textTheme.bodyLarge
                      : theme.textTheme.titleMedium,
                ),
                if (helper != null)
                  Text(
                    helper!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: '$label: ${S.decrease}',
                    onPressed: onDecrement,
                    icon: const Icon(Icons.remove),
                  ),
                  _value(theme),
                  IconButton.filledTonal(
                    tooltip: '$label: ${S.increase}',
                    onPressed: onIncrement,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              ?belowValue,
            ],
          ),
        ],
      ),
    );
  }

  // Fixed width so the buttons never move; long values shrink.
  Widget _value(ThemeData theme) => SizedBox(
    width: 96,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          valueText,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: NumberStyles.small.copyWith(
            fontSize: 24,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    ),
  );
}
