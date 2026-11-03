import 'package:flutter/material.dart';

import '../../../core/l10n/strings_de.dart';
import '../../../domain/models/models.dart';
import '../../../domain/set_validation.dart';
import 'set_input.dart';

sealed class SetEditResult {
  const SetEditResult();
}

final class SetEditSave extends SetEditResult {
  const SetEditSave(this.values);

  final SetValues values;
}

final class SetEditDelete extends SetEditResult {
  const SetEditDelete();
}

/// "Ändern/Löschen" for a recorded set (SPEC §6.2).
Future<SetEditResult?> showSetEditDialog(
  BuildContext context, {
  required Exercise exercise,
  required SetEntry set,
}) {
  return showDialog<SetEditResult>(
    context: context,
    builder: (_) => _SetEditDialog(exercise: exercise, set: set),
  );
}

class _SetEditDialog extends StatefulWidget {
  const _SetEditDialog({required this.exercise, required this.set});

  final Exercise exercise;
  final SetEntry set;

  @override
  State<_SetEditDialog> createState() => _SetEditDialogState();
}

class _SetEditDialogState extends State<_SetEditDialog> {
  late SetValues _values = SetValues(
    weightKg: widget.set.weightKg,
    reps: widget.set.reps,
    durationSec: widget.set.durationSec,
  );

  bool get _valid =>
      validateSet(
        widget.exercise.type,
        weightKg: _values.weightKg,
        reps: _values.reps,
        durationSec: _values.durationSec,
      ) ==
      null;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: Text(S.editSet(widget.set.setIndex)),
      content: SingleChildScrollView(
        child: SetInput(
          type: widget.exercise.type,
          incrementKg: widget.exercise.incrementKg,
          values: _values,
          showStopwatch: false,
          onChanged: (v) => setState(() => _values = v),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: error),
          onPressed: () => Navigator.of(context).pop(const SetEditDelete()),
          child: const Text(S.delete),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        TextButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop(SetEditSave(_values))
              : null,
          child: const Text(S.save),
        ),
      ],
    );
  }
}
