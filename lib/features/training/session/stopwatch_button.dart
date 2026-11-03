import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../core/theme/typography.dart';
import '../../../widgets/ticker.dart';

/// Large stopwatch for timed exercises: "Start" → running time → "Stopp"
/// hands the duration to [onStopped] (SPEC §6.2).
class StopwatchButton extends ConsumerStatefulWidget {
  const StopwatchButton({required this.onStopped, super.key});

  final ValueChanged<int> onStopped;

  @override
  ConsumerState<StopwatchButton> createState() => _StopwatchButtonState();
}

class _StopwatchButtonState extends ConsumerState<StopwatchButton> {
  DateTime? _startedAt;

  Clock get _clock => ref.read(clockProvider);

  void _toggle() {
    final start = _startedAt;
    if (start == null) {
      setState(() => _startedAt = _clock.now());
      return;
    }
    final seconds = _clock.now().difference(start).inSeconds;
    setState(() => _startedAt = null);
    widget.onStopped(seconds < 1 ? 1 : seconds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = _startedAt;
    final running = start != null;
    return SizedBox(
      height: 96,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          backgroundColor: running
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.secondaryContainer,
          foregroundColor: running
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onSecondaryContainer,
        ),
        onPressed: _toggle,
        child: running
            ? ClockTicker(
                interval: const Duration(milliseconds: 250),
                builder: (context, now) => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stop, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        formatMinSec(now.difference(start)),
                        style: NumberStyles.display.copyWith(fontSize: 48),
                      ),
                      const SizedBox(width: 12),
                      const Text(S.stopwatchStop),
                    ],
                  ),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow, size: 32),
                  SizedBox(width: 8),
                  Text(S.stopwatchStart, style: TextStyle(fontSize: 22)),
                ],
              ),
      ),
    );
  }
}
