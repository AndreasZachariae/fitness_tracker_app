import '../metrics.dart';
import '../models/models.dart';
import '../records.dart';
import '../weight_steps.dart';
import 'csv.dart';

/// The four CSV files of the export (SPEC §8.1), only finished sessions.
Map<String, String> buildCsvExport(Dataset data) {
  final exercises = {for (final e in data.exercises) e.id: e};
  final finished = [
    for (final s in data.sessions)
      if (!s.isActive) s,
  ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final sessionIds = {for (final s in finished) s.id};
  final sessionExercises = {
    for (final se in data.sessionExercises)
      if (sessionIds.contains(se.sessionId)) se.id: se,
  };
  final setsBySe = <int, List<SetEntry>>{};
  for (final set in data.sets) {
    if (sessionExercises.containsKey(set.sessionExerciseId)) {
      setsBySe.putIfAbsent(set.sessionExerciseId, () => []).add(set);
    }
  }
  final sessionsById = {for (final s in finished) s.id: s};

  final setRows = <List<Object?>>[];
  final ordered = sessionExercises.values.toList()
    ..sort((a, b) {
      final bySession = sessionsById[a.sessionId]!.startedAt.compareTo(
        sessionsById[b.sessionId]!.startedAt,
      );
      return bySession != 0 ? bySession : a.position.compareTo(b.position);
    });
  for (final se in ordered) {
    final session = sessionsById[se.sessionId]!;
    final e = exercises[se.exerciseId]!;
    final sets = (setsBySe[se.id] ?? [])
      ..sort((a, b) => a.setIndex.compareTo(b.setIndex));
    for (final set in sets) {
      setRows.add([
        session.id,
        LocalDate.fromDateTime(session.startedAt).toIsoString(),
        isoWithOffset(session.startedAt),
        session.planNameSnapshot,
        e.id,
        e.name,
        e.type.code,
        e.category?.code,
        se.position + 1,
        set.setIndex,
        set.weightKg,
        set.reps,
        set.durationSec,
        set.isWarmup,
        e.type == ExerciseType.weightReps && storesKg(e)
            ? estimatedOneRepMax(set.weightKg ?? 0, set.reps ?? 0)
            : null,
        isoWithOffset(set.completedAt),
        // 1.1.0: "level" = weight_kg holds a level number (levels without kg).
        storesKg(e) ? 'kg' : 'level',
      ]);
    }
  }

  final sessionRows = [
    for (final s in finished)
      () {
        final details = [
          for (final se in ordered)
            if (se.sessionId == s.id)
              SessionExerciseDetail(
                sessionExercise: se,
                exercise: exercises[se.exerciseId]!,
                sets: setsBySe[se.id] ?? const [],
              ),
        ];
        return <Object?>[
          s.id,
          s.planNameSnapshot,
          isoWithOffset(s.startedAt),
          isoWithOffset(s.endedAt!),
          s.endedAt!.difference(s.startedAt).inSeconds,
          details.where((d) => workingSets(d.sets).isNotEmpty).length,
          details.fold<int>(0, (n, d) => n + workingSets(d.sets).length),
          sessionVolume(details),
          s.notes,
        ];
      }(),
  ];

  final weights = [...data.bodyWeights]
    ..sort((a, b) => a.date.compareTo(b.date));
  final exerciseList = [...data.exercises]
    ..sort((a, b) => a.id.compareTo(b.id));

  return {
    'sets.csv': toCsv(const [
      'session_id',
      'session_date',
      'session_started_at',
      'plan_name',
      'exercise_id',
      'exercise_name',
      'exercise_type',
      'category',
      'exercise_position',
      'set_index',
      'weight_kg',
      'reps',
      'duration_s',
      'is_warmup',
      'e1rm_kg',
      'completed_at',
      'weight_unit',
    ], setRows),
    'sessions.csv': toCsv(const [
      'session_id',
      'plan_name',
      'started_at',
      'ended_at',
      'duration_s',
      'n_exercises',
      'n_sets',
      'volume_kg',
      'notes',
    ], sessionRows),
    'body_weight.csv': toCsv(
      const ['date', 'weight_kg'],
      [
        for (final w in weights) [w.date.toIsoString(), w.weightKg],
      ],
    ),
    'exercises.csv': toCsv(
      const [
        'exercise_id',
        'name',
        'type',
        'category',
        'increment_kg',
        'include_in_strength_index',
        'archived',
        'notes',
        'step_mode',
        'increment_lbs',
        'level_kg',
      ],
      [
        for (final e in exerciseList)
          [
            e.id,
            e.name,
            e.type.code,
            e.category?.code,
            e.incrementKg,
            e.includeInStrengthIndex,
            e.archived,
            e.notes,
            e.stepMode.code,
            e.incrementLbs,
            e.levelKg,
          ],
      ],
    ),
  };
}
