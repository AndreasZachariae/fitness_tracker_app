import 'package:flutter/material.dart';

import '../../core/format/exercise_format.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/repositories/plan_repository.dart';
import '../../domain/models/models.dart';
import '../../widgets/number_stepper.dart';
import '../settings/exercises/exercise_form_page.dart';

/// What the sheet asks its caller to do after closing.
enum PlanEntrySheetResult { editExercise }

/// Bottom sheet "Im Plan bearbeiten": sets, target reps/duration, rest.
/// Every change is passed to [onChanged] at once.
Future<PlanEntrySheetResult?> showPlanEntrySheet(
  BuildContext context, {
  required Exercise exercise,
  required ExerciseTargets targets,
  required int defaultRestSec,
  required bool isPlan,
  required ValueChanged<ExerciseTargets> onChanged,
}) {
  return showModalBottomSheet<PlanEntrySheetResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _PlanEntrySheet(
      exercise: exercise,
      initial: targets,
      defaultRestSec: exercise.restSec ?? defaultRestSec,
      isPlan: isPlan,
      onChanged: onChanged,
    ),
  );
}

class _PlanEntrySheet extends StatefulWidget {
  const _PlanEntrySheet({
    required this.exercise,
    required this.initial,
    required this.defaultRestSec,
    required this.isPlan,
    required this.onChanged,
  });

  final Exercise exercise;
  final ExerciseTargets initial;
  final int defaultRestSec;
  final bool isPlan;
  final ValueChanged<ExerciseTargets> onChanged;

  @override
  State<_PlanEntrySheet> createState() => _PlanEntrySheetState();
}

class _PlanEntrySheetState extends State<_PlanEntrySheet> {
  static const _restStep = 15;
  static const _maxRest = 600;

  late ExerciseTargets _t = widget.initial;

  void _set(ExerciseTargets t) {
    setState(() => _t = t);
    widget.onChanged(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.exercise;
    final rest = _t.restSec;
    final shownRest = rest ?? widget.defaultRestSec;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isPlan ? S.editInPlan : S.editInFreeList,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(e.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          NumberStepper(
            label: S.fieldSets,
            valueText: '${_t.sets}',
            onDecrement: _t.sets > minTargetSets
                ? () => _set(_t.copyWith(sets: _t.sets - 1))
                : null,
            onIncrement: _t.sets < maxTargetSets
                ? () => _set(_t.copyWith(sets: _t.sets + 1))
                : null,
          ),
          if (e.type == ExerciseType.timed)
            OptionalDurationStepper(
              label: S.fieldTargetDuration,
              value: _t.durationSec,
              onChanged: (v) => _set(_t.copyWith(durationSec: v)),
            )
          else
            OptionalRepsStepper(
              label: S.fieldTargetReps,
              value: _t.reps,
              onChanged: (v) => _set(_t.copyWith(reps: v)),
            ),
          NumberStepper(
            label: S.fieldRestShort,
            valueText: formatDuration(shownRest),
            helper: rest == null
                ? S.restDefault(formatDuration(widget.defaultRestSec))
                : null,
            onDecrement: shownRest > 0
                ? () => _set(
                    _t.copyWith(
                      restSec: (shownRest - _restStep).clamp(0, _maxRest),
                    ),
                  )
                : null,
            onIncrement: shownRest < _maxRest
                ? () => _set(
                    _t.copyWith(
                      restSec: (shownRest + _restStep).clamp(0, _maxRest),
                    ),
                  )
                : null,
          ),
          if (rest != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _set(_t.copyWith(restSec: null)),
                child: const Text(S.resetToDefault),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text(S.editExercise),
            onPressed: () =>
                Navigator.of(context).pop(PlanEntrySheetResult.editExercise),
          ),
        ],
      ),
    );
  }
}
