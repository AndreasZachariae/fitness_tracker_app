import 'package:flutter/material.dart';

import '../../../core/format/exercise_format.dart';
import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../domain/models/models.dart';
import '../../../domain/weight_steps.dart';
import '../../../widgets/big_stepper.dart';
import '../../../widgets/number_input_dialog.dart';
import 'stopwatch_button.dart';

/// Limits of the set input.
abstract final class SetLimits {
  static const maxWeight = 1000.0;
  static const minAssistance = -500.0;
  static const maxReps = 999;
  static const durationStep = 5;
  static const maxDuration = 36000;
}

double _round(double v) => (v * 100).round() / 100;

/// Asks for a weight; [allowNegative] for bodyweight assistance. With
/// [levels] the level is asked for and its stored weight returned (1.1.0).
Future<double?> askWeight(
  BuildContext context,
  double? current, {
  bool allowNegative = false,
  LevelStep? levels,
}) => levels != null
    ? showNumberInputDialog<double>(
        context,
        title: S.enterLevel,
        initialText: current == null
            ? ''
            : formatLevel(levels.levelOf(current)),
        decimal: true,
        parse: (t) {
          final v = parseDecimal(t);
          if (v == null || v < 0 || v > 1000) return null;
          final w = levels.weightOf(v);
          return w > SetLimits.maxWeight ? null : w;
        },
      )
    : showNumberInputDialog<double>(
        context,
        title: S.enterWeight,
        initialText: current == null ? '' : formatWeight(current),
        decimal: true,
        parse: (t) {
          final v = parseDecimal(t);
          if (v == null || v > SetLimits.maxWeight) return null;
          if (v < (allowNegative ? SetLimits.minAssistance : 0)) return null;
          return _round(v);
        },
      );

Future<int?> askReps(BuildContext context, int? current) =>
    showNumberInputDialog<int>(
      context,
      title: S.enterReps,
      initialText: current?.toString() ?? '',
      parse: (t) {
        final v = int.tryParse(t.trim());
        return v != null && v >= 1 && v <= SetLimits.maxReps ? v : null;
      },
    );

Future<int?> askDuration(BuildContext context, int? current) =>
    showNumberInputDialog<int>(
      context,
      title: S.enterDuration,
      initialText: current == null
          ? ''
          : formatMinSec(Duration(seconds: current)),
      parse: (t) {
        final v = parseDurationInput(t);
        return v != null && v <= SetLimits.maxDuration ? v : null;
      },
    );

/// The input area of a set for one exercise type (SPEC §6.2).
class SetInput extends StatefulWidget {
  const SetInput({
    required this.type,
    required this.step,
    required this.values,
    required this.onChanged,
    this.showStopwatch = true,
    super.key,
  });

  final ExerciseType type;

  /// How + and − move the weight (kg step, lbs plates, levels; 1.1.0).
  final WeightStep step;
  final SetValues values;
  final ValueChanged<SetValues> onChanged;

  /// `false` when editing a stored set.
  final bool showStopwatch;

  @override
  State<SetInput> createState() => _SetInputState();
}

class _SetInputState extends State<SetInput> {
  late bool _showTimedWeight = (widget.values.weightKg ?? 0) > 0;

  /// Latest values, updated at once so quick taps before the next frame
  /// build on each other instead of overwriting each other.
  late SetValues _current = widget.values;

  @override
  void didUpdateWidget(SetInput old) {
    super.didUpdateWidget(old);
    _current = widget.values;
  }

  SetValues get _v => _current;

  void _emit(SetValues v) {
    _current = v;
    widget.onChanged(v);
  }

  Widget _weight({required bool signed, required bool allowNegative}) {
    final w = _v.weightKg;
    final step = widget.step;
    // Levels only for weight × reps exercises.
    final levels = widget.type == ExerciseType.weightReps && step is LevelStep
        ? step
        : null;
    final min = allowNegative ? SetLimits.minAssistance : 0.0;
    Future<void> ask() async {
      final v = await askWeight(
        context,
        w,
        allowNegative: allowNegative,
        levels: levels,
      );
      if (v != null) _emit(_v.copyWith(weightKg: v));
    }

    final down = w == null ? null : step.down(w);
    final up = w == null ? null : step.up(w);
    return BigStepper(
      label: levels == null
          ? (signed ? S.addedWeight : S.weight)
          : w == null || levels.kgPerLevel == null
          ? S.level
          : '${S.level} · ${formatKg(w)}',
      valueText: switch (w) {
        null => levels == null ? '– ${S.unitKg}' : '–',
        final w when levels != null => formatLevel(levels.levelOf(w)),
        final w => signed ? formatSignedKg(w) : formatKg(w),
      },
      onDecrement: w == null
          ? ask
          : down! >= min - 1e-9
          ? () => _emit(_v.copyWith(weightKg: _round(down)))
          : (w > min ? () => _emit(_v.copyWith(weightKg: min)) : null),
      onIncrement: w == null
          ? ask
          : up! <= SetLimits.maxWeight
          ? () => _emit(_v.copyWith(weightKg: _round(up)))
          : null,
      onTapValue: ask,
    );
  }

  Widget _reps() {
    final r = _v.reps;
    Future<void> ask() async {
      final v = await askReps(context, r);
      if (v != null) _emit(_v.copyWith(reps: v));
    }

    return BigStepper(
      label: S.reps,
      valueText: r?.toString() ?? '–',
      onDecrement: r == null
          ? ask
          : r > 1
          ? () => _emit(_v.copyWith(reps: r - 1))
          : null,
      onIncrement: r == null
          ? ask
          : r < SetLimits.maxReps
          ? () => _emit(_v.copyWith(reps: r + 1))
          : null,
      onTapValue: ask,
    );
  }

  Widget _duration() {
    final d = _v.durationSec;
    const step = SetLimits.durationStep;
    Future<void> ask() async {
      final v = await askDuration(context, d);
      if (v != null) _emit(_v.copyWith(durationSec: v));
    }

    return BigStepper(
      label: S.duration,
      valueText: d == null ? '–:––' : formatMinSec(Duration(seconds: d)),
      onDecrement: d == null
          ? ask
          : d > step
          ? () => _emit(_v.copyWith(durationSec: d - step))
          : null,
      onIncrement: d == null
          ? ask
          : d + step <= SetLimits.maxDuration
          ? () => _emit(_v.copyWith(durationSec: d + step))
          : null,
      onTapValue: ask,
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return switch (widget.type) {
      ExerciseType.weightReps => Column(
        children: [_weight(signed: false, allowNegative: false), gap, _reps()],
      ),
      ExerciseType.bodyweight => Column(
        children: [_weight(signed: true, allowNegative: true), gap, _reps()],
      ),
      ExerciseType.timed => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showStopwatch) ...[
            StopwatchButton(
              onStopped: (s) => _emit(_v.copyWith(durationSec: s)),
            ),
            gap,
          ],
          _duration(),
          if (_showTimedWeight) ...[
            gap,
            _weight(signed: true, allowNegative: false),
          ] else
            Align(
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text(S.addWeight),
                onPressed: () => setState(() {
                  _showTimedWeight = true;
                  if (_v.weightKg == null) _emit(_v.copyWith(weightKg: 0.0));
                }),
              ),
            ),
        ],
      ),
    };
  }
}
