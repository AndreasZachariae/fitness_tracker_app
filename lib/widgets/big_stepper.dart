import 'package:flutter/material.dart';

import '../core/l10n/strings_de.dart';
import '../core/theme/typography.dart';

/// Large stepper for the set input: `[−] 62,5 kg [+]` with 56 dp buttons and
/// numbers ≥ 32 sp. Tapping the number calls [onTapValue] (direct input).
class BigStepper extends StatelessWidget {
  const BigStepper({
    required this.label,
    required this.valueText,
    required this.onDecrement,
    required this.onIncrement,
    required this.onTapValue,
    super.key,
  });

  final String label;
  final String valueText;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final VoidCallback onTapValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const buttonSize = Size.square(56);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: '$label: ${S.decrease}',
              style: IconButton.styleFrom(minimumSize: buttonSize),
              onPressed: onDecrement,
              icon: const Icon(Icons.remove, size: 28),
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: '$label: $valueText',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTapValue,
                  child: SizedBox(
                    height: 64,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            valueText,
                            maxLines: 1,
                            style: NumberStyles.large.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: '$label: ${S.increase}',
              style: IconButton.styleFrom(minimumSize: buttonSize),
              onPressed: onIncrement,
              icon: const Icon(Icons.add, size: 28),
            ),
          ],
        ),
      ],
    );
  }
}
