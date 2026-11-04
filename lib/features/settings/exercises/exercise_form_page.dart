import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/exercise_format.dart';
import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/plan_repository.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../../domain/models/models.dart';
import '../../../domain/names.dart';
import '../../../widgets/info_button.dart';
import '../../../widgets/number_stepper.dart';
import '../../../widgets/snackbars.dart';
import 'exercise_actions.dart';

/// Result of the exercise form.
final class ExerciseFormResult {
  const ExerciseFormResult({required this.exerciseId, this.targets});

  final int exerciseId;

  /// Set when the form was opened with targets (new exercise for a list).
  final ExerciseTargets? targets;
}

/// Opens the form full screen above the tabs.
///
/// [exercise] = edit, otherwise create. [withTargets] additionally asks for
/// target sets and reps/duration (SPEC §6.1 "Neue Übung anlegen").
Future<ExerciseFormResult?> openExerciseForm(
  BuildContext context, {
  Exercise? exercise,
  bool withTargets = false,
  String initialName = '',
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<ExerciseFormResult>(
      fullscreenDialog: exercise == null,
      builder: (_) => ExerciseFormPage(
        exercise: exercise,
        withTargets: withTargets,
        initialName: initialName,
      ),
    ),
  );
}

class ExerciseFormPage extends ConsumerStatefulWidget {
  const ExerciseFormPage({
    this.exercise,
    this.withTargets = false,
    this.initialName = '',
    super.key,
  });

  final Exercise? exercise;
  final bool withTargets;
  final String initialName;

  @override
  ConsumerState<ExerciseFormPage> createState() => _ExerciseFormPageState();
}

class _ExerciseFormPageState extends ConsumerState<ExerciseFormPage> {
  late final Exercise? _original = widget.exercise;
  late final _name = TextEditingController(
    text: _original?.name ?? widget.initialName,
  );
  late final _increment = TextEditingController(
    text: formatWeight(
      _original?.incrementKg ?? ExerciseDraft.defaultIncrementKg,
    ),
  );
  late final _rest = TextEditingController(
    text: _original?.restSec?.toString() ?? '',
  );
  late final _notes = TextEditingController(text: _original?.notes ?? '');

  late ExerciseType _type = _original?.type ?? ExerciseType.weightReps;
  late ExerciseCategory? _category = _original?.category;
  late bool _inIndex =
      _original?.includeInStrengthIndex ??
      _type.includeInStrengthIndexByDefault;
  bool _inIndexTouched = false;

  /// `true` while unknown, so the type cannot change before we know.
  bool _typeLocked = true;

  int? _sets;
  int? _reps;
  int? _duration;

  String? _nameError;
  String? _incrementError;
  String? _restError;
  bool _busy = false;

  bool get _isNew => _original == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _typeLocked = false;
    } else {
      ref.read(exerciseRepositoryProvider).hasHistory(_original!.id).then((
        locked,
      ) {
        if (mounted) setState(() => _typeLocked = locked);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _increment.dispose();
    _rest.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _setType(ExerciseType type) => setState(() {
    _type = type;
    if (_isNew && !_inIndexTouched) {
      _inIndex = type.includeInStrengthIndexByDefault;
    }
  });

  Future<void> _save() async {
    final name = cleanName(_name.text);
    final increment = parseDecimal(_increment.text);
    final restText = _rest.text.trim();
    final rest = restText.isEmpty ? null : int.tryParse(restText);
    setState(() {
      _nameError = name.isEmpty
          ? S.errorNameRequired
          : name.length > maxNameLength
          ? S.errorNameTooLong
          : null;
      _incrementError = increment == null || increment <= 0 || increment > 100
          ? S.errorIncrement
          : null;
      _restError =
          restText.isNotEmpty && (rest == null || rest < 0 || rest > 3600)
          ? S.errorRest
          : null;
    });
    if (_nameError != null || _incrementError != null || _restError != null) {
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(exerciseRepositoryProvider);
    try {
      final int id;
      if (_isNew) {
        id = await repo.create(
          ExerciseDraft(
            name: name,
            type: _type,
            category: _category,
            incrementKg: increment!,
            restSec: rest,
            includeInStrengthIndex: _inIndex,
            notes: _notes.text,
          ),
        );
      } else {
        id = _original!.id;
        await repo.update(
          _original.copyWith(
            name: name,
            type: _type,
            category: _category,
            incrementKg: increment,
            restSec: rest,
            includeInStrengthIndex: _inIndex,
            notes: _notes.text,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        ExerciseFormResult(
          exerciseId: id,
          targets: widget.withTargets ? _targets() : null,
        ),
      );
    } on DuplicateNameException {
      setState(() {
        _busy = false;
        _nameError = S.errorExerciseNameTaken;
      });
    } on Object catch (e) {
      setState(() => _busy = false);
      if (mounted) showError(context, e);
    }
  }

  ExerciseTargets _targets() {
    final defaults = ref.read(settingsProvider).value ?? AppSettings.defaults;
    return ExerciseTargets(
      sets: _sets ?? defaults.defaultSets,
      reps: _type == ExerciseType.timed ? null : _reps,
      durationSec: _type == ExerciseType.timed ? _duration : null,
    );
  }

  Future<void> _remove() async {
    final removed = await removeExerciseWithConfirmation(
      context,
      ref,
      _original!,
    );
    if (removed && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).value ?? AppSettings.defaults;
    final sets = _sets ?? settings.defaultSets;
    const gap = SizedBox(height: 20);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? S.newExercise : S.editExercise),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: S.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _remove,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  TextField(
                    controller: _name,
                    autofocus: _isNew && widget.initialName.isEmpty,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: maxNameLength,
                    decoration: InputDecoration(
                      labelText: S.fieldName,
                      errorText: _nameError,
                      counterText: '',
                    ),
                  ),
                  gap,
                  const _Label(S.fieldType),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in ExerciseType.values)
                        ChoiceChip(
                          label: Text(S.exerciseType(t)),
                          selected: _type == t,
                          onSelected: _typeLocked || _busy
                              ? null
                              : (_) => _setType(t),
                        ),
                    ],
                  ),
                  if (_typeLocked && !_isNew)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        S.typeLocked,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  gap,
                  const _Label('${S.fieldCategory} (${S.optional})'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in ExerciseCategory.values)
                        ChoiceChip(
                          label: Text(S.category(c)),
                          selected: _category == c,
                          onSelected: (selected) =>
                              setState(() => _category = selected ? c : null),
                        ),
                    ],
                  ),
                  if (widget.withTargets) ...[
                    gap,
                    NumberStepper(
                      label: S.fieldTargetSets,
                      valueText: '$sets',
                      onDecrement: sets > minTargetSets
                          ? () => setState(() => _sets = sets - 1)
                          : null,
                      onIncrement: sets < maxTargetSets
                          ? () => setState(() => _sets = sets + 1)
                          : null,
                    ),
                    if (_type == ExerciseType.timed)
                      OptionalDurationStepper(
                        label: S.fieldTargetDuration,
                        value: _duration,
                        onChanged: (v) => setState(() => _duration = v),
                      )
                    else
                      OptionalRepsStepper(
                        label: S.fieldTargetReps,
                        value: _reps,
                        onChanged: (v) => setState(() => _reps = v),
                      ),
                  ],
                  gap,
                  TextField(
                    controller: _increment,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: S.fieldIncrement,
                      errorText: _incrementError,
                    ),
                  ),
                  gap,
                  TextField(
                    controller: _rest,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${S.fieldRest} (${S.optional})',
                      hintText: S.fieldRestHint(settings.defaultRestSec),
                      errorText: _restError,
                    ),
                  ),
                  gap,
                  TextField(
                    controller: _notes,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: '${S.fieldNotes} (${S.optional})',
                      hintText: S.fieldNotesHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(S.fieldStrengthIndex),
                          value: _inIndex,
                          onChanged: (v) => setState(() {
                            _inIndex = v;
                            _inIndexTouched = true;
                          }),
                        ),
                      ),
                      const InfoButton(
                        title: S.strengthIndex,
                        text: S.strengthIndexFieldInfo,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text(S.save),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Stepper for an optional rep target: "ohne Ziel" ↔ 1 … 100.
class OptionalRepsStepper extends StatelessWidget {
  const OptionalRepsStepper({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  static const startValue = 10;
  static const maxValue = 100;

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return NumberStepper(
      label: label,
      valueText: v?.toString() ?? '–',
      helper: v == null ? S.noTarget : null,
      onDecrement: v == null ? null : () => onChanged(v <= 1 ? null : v - 1),
      onIncrement: v == null
          ? () => onChanged(startValue)
          : v < maxValue
          ? () => onChanged(v + 1)
          : null,
    );
  }
}

/// Stepper for an optional duration target in 5 s steps:
/// "ohne Ziel" ↔ 5 s … 60 min.
class OptionalDurationStepper extends StatelessWidget {
  const OptionalDurationStepper({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  static const step = 5;
  static const startValue = 30;
  static const maxValue = 3600;

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return NumberStepper(
      label: label,
      valueText: v == null ? '–' : formatDuration(v),
      helper: v == null ? S.noTarget : null,
      onDecrement: v == null
          ? null
          : () => onChanged(v <= step ? null : v - step),
      onIncrement: v == null
          ? () => onChanged(startValue)
          : v < maxValue
          ? () => onChanged(v + step)
          : null,
    );
  }
}
