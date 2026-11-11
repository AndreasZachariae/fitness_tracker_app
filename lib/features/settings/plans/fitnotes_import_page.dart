import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../data/io/fitnotes_import_service.dart';
import '../../../data/providers.dart';
import '../../../domain/fitnotes_import.dart';
import '../../../domain/models/models.dart';
import '../../../domain/names.dart';
import '../../../widgets/snackbars.dart';
import 'plan_page.dart';

/// Settings → Pläne → "Plan aus FitNotes importieren" (1.4.0): picks the
/// text file of a FitNotes workout, shows the preview and opens the new
/// plan's page for its training days.
Future<void> importFitNotesPlan(BuildContext context, WidgetRef ref) async {
  final bytes = await ref.read(fileGatewayProvider).pickFile();
  if (bytes == null || !context.mounted) return;
  final FitNotesWorkout workout;
  try {
    workout = parseFitNotes(utf8.decode(bytes, allowMalformed: true));
  } on FitNotesFormatException catch (e) {
    showMessage(
      context,
      e.message.contains('more than one')
          ? S.importSeveralWorkouts
          : S.importNotFitNotes,
    );
    return;
  }
  final exercises = await ref.read(exerciseRepositoryProvider).getAll();
  final plans = await ref.read(planRepositoryProvider).getPlans();
  final running = await ref.read(sessionRepositoryProvider).getActive();
  if (!context.mounted) return;
  final result = await Navigator.of(context).push(
    MaterialPageRoute<(String, FitNotesImportResult)>(
      builder: (_) => FitNotesImportPage(
        workout: workout,
        exercises: exercises,
        planNames: [for (final p in plans) p.name],
        trainingRunning: running != null,
      ),
    ),
  );
  if (result == null || !context.mounted) return;
  final (name, done) = result;
  showMessage(context, S.importDone(name, done.newExercises));
  await openPlanPage(context, done.planId);
}

/// The preview: plan name, which GymLog exercise each FitNotes exercise
/// becomes, and whether the workout also goes into the history.
class FitNotesImportPage extends ConsumerStatefulWidget {
  const FitNotesImportPage({
    required this.workout,
    required this.exercises,
    required this.planNames,
    required this.trainingRunning,
    super.key,
  });

  final FitNotesWorkout workout;

  /// All exercises of GymLog (archived ones are never offered).
  final List<Exercise> exercises;
  final List<String> planNames;

  /// A running training blocks importing the workout as a training.
  final bool trainingRunning;

  @override
  ConsumerState<FitNotesImportPage> createState() => _FitNotesImportPageState();
}

class _FitNotesImportPageState extends ConsumerState<FitNotesImportPage> {
  late final TextEditingController _name;
  late final List<int?> _targets;
  late bool _withTraining = !widget.trainingRunning;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _defaultName());
    // Suggestions: same name or a known FitNotes name; never twice.
    final used = <int>{};
    _targets = [];
    for (final source in widget.workout.exercises) {
      final match = suggestExercise(source, [
        for (final e in widget.exercises)
          if (!used.contains(e.id)) e,
      ]);
      if (match != null) used.add(match.id);
      _targets.add(match?.id);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _defaultName() {
    final base = widget.workout.dayLabel ?? 'FitNotes';
    final taken = {for (final n in widget.planNames) nameKey(n)};
    if (!taken.contains(nameKey(base))) return base;
    for (var i = 2; ; i++) {
      if (!taken.contains(nameKey('$base $i'))) return '$base $i';
    }
  }

  String? get _nameError {
    final name = _name.text;
    if (cleanName(name).isEmpty) return S.errorNameRequired;
    if (!isValidName(name)) return S.errorNameTooLong;
    if (widget.planNames.any((p) => nameKey(p) == nameKey(name))) {
      return S.errorPlanNameTaken;
    }
    return null;
  }

  Exercise? _exercise(int? id) =>
      id == null ? null : widget.exercises.where((e) => e.id == id).firstOrNull;

  Future<void> _choose(int index) async {
    final source = widget.workout.exercises[index];
    final usedElsewhere = {
      for (final (i, t) in _targets.indexed)
        if (i != index && t != null) t,
    };
    final options = [
      for (final e in widget.exercises)
        if (canImportInto(source, e) && !usedElsewhere.contains(e.id)) e,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final picked = await showModalBottomSheet<_Choice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ChooseSheet(source: source, options: options),
    );
    if (picked != null && mounted) {
      setState(() => _targets[index] = picked.exerciseId);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final name = cleanName(_name.text);
      final result = await ref
          .read(fitNotesImportProvider)
          .import(
            widget.workout,
            planName: name,
            targets: _targets,
            withTraining: _withTraining && !widget.trainingRunning,
          );
      if (mounted) Navigator.of(context).pop((name, result));
    } on Object catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  String _sets(FitNotesExercise e) {
    final count = e.targetSets;
    final weight = e.typicalWeightKg;
    return switch (e.type) {
      ExerciseType.timed =>
        '$count × ${formatMinSec(Duration(seconds: e.targetDurationSec ?? 0))}'
            '${weight == null ? '' : ' · ${formatKg(weight)}'}',
      _ =>
        '$count × ${e.targetReps ?? '–'}'
            '${weight == null ? '' : ' · ${formatKg(weight)}'}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = widget.workout;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final date = w.date;
    return Scaffold(
      appBar: AppBar(title: const Text(S.importFitNotesTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: S.importPlanName,
                errorText: _nameError,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(S.importSummary(w.exercises.length, w.setCount)),
          ),
          if (w.skippedSets > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(S.importSkippedSets(w.skippedSets), style: muted),
            ),
          if (w.unreadLines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                S.importUnreadLines(w.unreadLines.length, w.unreadLines.first),
                style: muted,
              ),
            ),
          SwitchListTile(
            value: _withTraining && !widget.trainingRunning,
            onChanged: widget.trainingRunning
                ? null
                : (v) => setState(() => _withTraining = v),
            title: Text(
              date == null
                  ? S.importTrainingToday
                  : S.importTrainingFrom(
                      formatWeekdayDateYear(date.toLocalDateTime()),
                    ),
            ),
            subtitle: Text(
              widget.trainingRunning
                  ? S.importTrainingBlocked
                  : S.importTrainingHint,
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              S.importExercisesSection,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Text(S.importExercisesHint, style: muted),
          ),
          for (final (i, source) in w.exercises.indexed)
            _ExerciseRow(
              source: source,
              sets: _sets(source),
              target: _exercise(_targets[i]),
              onTap: _busy ? null : () => _choose(i),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            icon: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(Icons.download_done),
            label: const Text(S.importStart),
            onPressed: _busy || _nameError != null ? null : _import,
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.source,
    required this.sets,
    required this.target,
    required this.onTap,
  });

  final FitNotesExercise source;
  final String sets;
  final Exercise? target;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = source.group;
    final groupText = switch (source.groupKind) {
      PlanGroupKind.rotation => S.importRotation(group!),
      PlanGroupKind.superset => S.importSuperset(group!),
      null => null,
    };
    final target = this.target;
    return ListTile(
      onTap: onTap,
      title: Text(source.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${S.exerciseType(source.type)} · $sets'),
          if (groupText != null) Text(groupText),
          Text(
            target == null
                ? S.importNewExercise(source.name)
                : S.importExisting(target.name),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.edit_outlined),
    );
  }
}

/// The choice in the sheet: an existing exercise or null for a new one.
final class _Choice {
  const _Choice(this.exerciseId);

  final int? exerciseId;
}

class _ChooseSheet extends StatefulWidget {
  const _ChooseSheet({required this.source, required this.options});

  final FitNotesExercise source;
  final List<Exercise> options;

  @override
  State<_ChooseSheet> createState() => _ChooseSheetState();
}

class _ChooseSheetState extends State<_ChooseSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = nameKey(_query);
    final shown = [
      for (final e in widget.options)
        if (q.isEmpty || nameKey(e.name).contains(q)) e,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  S.importChooseTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(S.importCreateNew(widget.source.name)),
                onTap: () => Navigator.pop(context, const _Choice(null)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: S.search,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Flexible(
                child: shown.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(S.importNoMatches),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final e in shown)
                            ListTile(
                              title: Text(e.name),
                              subtitle: Text(S.exerciseType(e.type)),
                              onTap: () =>
                                  Navigator.pop(context, _Choice(e.id)),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
