import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/exercise_format.dart';
import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/plan_repository.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../../domain/heart_rate_zones.dart';
import '../../../domain/models/models.dart';
import '../../../domain/names.dart';
import '../../../domain/weight_steps.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/info_button.dart';
import '../../../widgets/number_stepper.dart';
import '../../../widgets/snackbars.dart';
import '../../heart_rate/zone_colors.dart';
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
  late final _incrementLbs = TextEditingController(
    text: formatWeight(_original?.incrementLbs ?? Exercise.defaultIncrementLbs),
  );
  late final _levelKg = TextEditingController(
    text: _original?.levelKg == null ? '' : formatWeight(_original!.levelKg!),
  );

  /// New exercises follow the default step of the settings (1.1.0).
  late StepMode _stepMode = _original?.stepMode ?? StepMode.standard;

  /// Unit of an own step ("Eigene").
  late WeightUnit _customUnit = _original?.stepMode == StepMode.lbs
      ? WeightUnit.lbs
      : WeightUnit.kg;
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

  // 1.6.0: pause by heart rate, heart rate target (warm-up / cardio).
  late bool _restByHr = _original?.restByHeartRate ?? false;
  late _TargetKind _targetKind = _original?.hrTargetZone != null
      ? _TargetKind.zone
      : _original?.hrTargetBpm != null
      ? _TargetKind.bpm
      : _TargetKind.none;
  late int _targetZone = _original?.hrTargetZone ?? 2;
  late final _targetBpm = TextEditingController(
    text: _original?.hrTargetBpm?.toString() ?? '',
  );
  late final _targetMinutes = TextEditingController(
    text: (_original?.hrTargetMinutes ?? 8).toString(),
  );
  String? _targetError;

  int? _sets;
  int? _reps;
  int? _duration;

  String? _nameError;
  String? _incrementError;
  String? _levelKgError;
  String? _restError;
  bool _busy = false;

  bool get _isNew => _original == null;

  void _update(VoidCallback change) => setState(change);

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
    _incrementLbs.dispose();
    _levelKg.dispose();
    _rest.dispose();
    _notes.dispose();
    _targetBpm.dispose();
    _targetMinutes.dispose();
    super.dispose();
  }

  void _setType(ExerciseType type) => setState(() {
    _type = type;
    // Levels only for weight × reps.
    if (type != ExerciseType.weightReps && _stepMode == StepMode.levels) {
      _stepMode = StepMode.standard;
    }
    if (_isNew && !_inIndexTouched) {
      _inIndex = type.includeInStrengthIndexByDefault;
    }
  });

  Future<void> _save() async {
    final name = cleanName(_name.text);
    final custom = _stepMode == StepMode.kg || _stepMode == StepMode.lbs;
    final increment = custom && _customUnit == WeightUnit.kg
        ? parseDecimal(_increment.text)
        : (_original?.incrementKg ?? ExerciseDraft.defaultIncrementKg);
    final incrementLbs = custom && _customUnit == WeightUnit.lbs
        ? parseDecimal(_incrementLbs.text)
        : (_original?.incrementLbs ?? Exercise.defaultIncrementLbs);
    final levelText = _levelKg.text.trim();
    final levelKg = _stepMode != StepMode.levels
        ? _original?.levelKg
        : (levelText.isEmpty ? null : parseDecimal(levelText));
    final levelInvalid =
        _stepMode == StepMode.levels &&
        levelText.isNotEmpty &&
        (levelKg == null || levelKg <= 0 || levelKg > 100);
    final mode = custom
        ? (_customUnit == WeightUnit.kg ? StepMode.kg : StepMode.lbs)
        : _stepMode;
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
          : incrementLbs == null || incrementLbs <= 0 || incrementLbs > 200
          ? S.errorStepLbs
          : null;
      _levelKgError = levelInvalid ? S.errorLevelKg : null;
      _restError =
          restText.isNotEmpty && (rest == null || rest < 0 || rest > 3600)
          ? S.errorRest
          : null;
      _targetError = _target == null && _hasTarget ? S.errorHrTarget : null;
    });
    if (_nameError != null ||
        _incrementError != null ||
        _levelKgError != null ||
        _restError != null ||
        _targetError != null) {
      return;
    }
    final target = _hasTarget ? _target : null;
    if (!await _confirmConversion(mode, levelKg)) return;

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
            stepMode: mode,
            incrementLbs: incrementLbs!,
            levelKg: levelKg,
            restByHeartRate: _restByHr,
            hrTargetZone: target?.zone,
            hrTargetBpm: target?.bpm,
            hrTargetMinutes: target?.minutes,
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
            stepMode: mode,
            incrementLbs: incrementLbs,
            levelKg: levelKg,
            restByHeartRate: _restByHr,
            hrTargetZone: target?.zone,
            hrTargetBpm: target?.bpm,
            hrTargetMinutes: target?.minutes,
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

  /// Logged sets of levels without kg store level numbers (1.1.0); asks
  /// before they are converted to kg or back.
  Future<bool> _confirmConversion(StepMode mode, double? levelKg) async {
    final original = _original;
    if (original == null || !_typeLocked) return true;
    final changed = original.copyWith(stepMode: mode, levelKg: levelKg);
    final fromKg = storesKg(original);
    if (fromKg == storesKg(changed)) return true;
    final kg = fromKg ? original.levelKg : levelKg;
    // Without kg per level the repository refuses with a message.
    if (kg == null) return true;
    return showConfirmDialog(
      context,
      title: fromKg ? S.convertToLevelsTitle : S.convertToKgTitle,
      body: fromKg
          ? S.convertToLevelsBody(formatKg(kg))
          : S.convertToKgBody(formatKg(kg)),
      confirmLabel: S.convert,
    );
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
                  _stepSection(settings),
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
                  _heartRateSection(settings),
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

/// Heart rate target of a warm-up / cardio exercise (1.6.0).
enum _TargetKind { none, zone, bpm }

extension on _ExerciseFormPageState {
  bool get _hasTarget =>
      _type == ExerciseType.timed && _targetKind != _TargetKind.none;

  /// The target as entered; null if invalid.
  ({int? zone, int? bpm, int minutes})? get _target {
    final minutes = int.tryParse(_targetMinutes.text.trim());
    if (minutes == null || minutes < 1 || minutes > 180) return null;
    if (_targetKind == _TargetKind.zone) {
      return (zone: _targetZone, bpm: null, minutes: minutes);
    }
    final bpm = int.tryParse(_targetBpm.text.trim());
    if (bpm == null || bpm < 40 || bpm > 250) return null;
    return (zone: null, bpm: bpm, minutes: minutes);
  }

  /// "Pause nach Puls" and, for timed exercises, the heart rate target.
  Widget _heartRateSection(AppSettings settings) {
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final pause = settings.pauseBpm;
    final threshold = settings.hrThreshold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const ValueKey('rest-by-hr'),
          contentPadding: EdgeInsets.zero,
          title: const Text(S.fieldRestByHr),
          subtitle: Text(
            pause == null
                ? S.fieldRestByHrNoProfile
                : S.fieldRestByHrHint(pause),
          ),
          value: _restByHr,
          onChanged: (v) => _update(() => _restByHr = v),
        ),
        if (_type == ExerciseType.timed) ...[
          const SizedBox(height: 8),
          Text(S.fieldHrTarget, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<_TargetKind>(
            segments: const [
              ButtonSegment(
                value: _TargetKind.none,
                label: Text(S.hrTargetNone),
              ),
              ButtonSegment(
                value: _TargetKind.zone,
                label: Text(S.hrTargetZoneKind),
              ),
              ButtonSegment(value: _TargetKind.bpm, label: Text(S.unitBpm)),
            ],
            selected: {_targetKind},
            showSelectedIcon: false,
            onSelectionChanged: (v) => _update(() => _targetKind = v.first),
          ),
          if (_targetKind == _TargetKind.zone) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var r = 1; r <= 5; r++)
                  ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: zoneColor(r)),
                    label: Text(
                      threshold == null
                          ? S.hrZone(r)
                          : '${S.hrZone(r)} · '
                                '${S.hrZoneBpm(heartRateZones(threshold)[r - 1].from, heartRateZones(threshold)[r - 1].to)}',
                    ),
                    selected: _targetZone == r,
                    onSelected: (_) => _update(() => _targetZone = r),
                  ),
              ],
            ),
            if (threshold == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(S.hrTargetNeedsProfile, style: hint),
              ),
          ],
          if (_targetKind == _TargetKind.bpm)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                key: const ValueKey('hr-target-bpm'),
                controller: _targetBpm,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: S.hrTargetBpmLabel,
                  suffixText: S.unitBpm,
                ),
              ),
            ),
          if (_targetKind != _TargetKind.none) ...[
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('hr-target-minutes'),
              controller: _targetMinutes,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: S.hrTargetMinutesLabel,
                suffixText: S.unitMinutes,
                errorText: _targetError,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _targetKind == _TargetKind.zone
                  ? S.hrTargetZoneHint
                  : S.hrTargetBpmHint,
              style: hint,
            ),
          ],
        ],
      ],
    );
  }

  /// "Gewichtsschritte": Standard / Eigene (kg or lbs) / Stufen (1.1.0).
  Widget _stepSection(AppSettings settings) {
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final custom = _stepMode == StepMode.kg || _stepMode == StepMode.lbs;
    final selected = custom ? StepMode.kg : _stepMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        const _Label(S.fieldStep),
        SegmentedButton<StepMode>(
          showSelectedIcon: false,
          segments: [
            const ButtonSegment(
              value: StepMode.standard,
              label: Text(S.stepStandard),
            ),
            const ButtonSegment(value: StepMode.kg, label: Text(S.stepCustom)),
            if (_type == ExerciseType.weightReps)
              const ButtonSegment(
                value: StepMode.levels,
                label: Text(S.stepLevels),
              ),
          ],
          selected: {selected},
          onSelectionChanged: (v) => _update(() {
            _stepMode = v.single == StepMode.kg
                ? (_customUnit == WeightUnit.kg ? StepMode.kg : StepMode.lbs)
                : v.single;
          }),
        ),
        if (_stepMode == StepMode.standard)
          Text(
            S.stepStandardHint(
              '${formatWeight(settings.defaultStep)} '
              '${S.unit(settings.defaultStepUnit)}',
            ),
            style: hintStyle,
          ),
        if (custom) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('step-value'),
                  controller: _customUnit == WeightUnit.kg
                      ? _increment
                      : _incrementLbs,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '${S.fieldStepValue} (${S.unit(_customUnit)})',
                    errorText: _incrementError,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SegmentedButton<WeightUnit>(
                  showSelectedIcon: false,
                  segments: [
                    for (final u in WeightUnit.values)
                      ButtonSegment(value: u, label: Text(S.unit(u))),
                  ],
                  selected: {_customUnit},
                  onSelectionChanged: (v) => _update(() {
                    _customUnit = v.single;
                    _stepMode = v.single == WeightUnit.kg
                        ? StepMode.kg
                        : StepMode.lbs;
                    _incrementError = null;
                  }),
                ),
              ),
            ],
          ),
          if (_customUnit == WeightUnit.lbs)
            Text(S.stepLbsHint, style: hintStyle),
        ],
        if (_stepMode == StepMode.levels) ...[
          TextField(
            controller: _levelKg,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: S.fieldLevelKg,
              hintText: S.fieldLevelKgHint,
              errorText: _levelKgError,
            ),
          ),
          Text(S.stepLevelsHint, style: hintStyle),
        ],
      ],
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
