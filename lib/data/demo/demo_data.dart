import 'dart:math';

import '../../domain/models/models.dart';
import '../db/storage_time.dart';

/// Generates a realistic, deterministic demo dataset (DEV app only):
/// [weeks] weeks up to [now], two plans plus free trainings, 13 exercises of
/// all types (one archived), progression with noise, skipped weeks and body
/// weight 3–5 times per week with a slight downward trend.
Dataset generateDemoData({
  required DateTime now,
  int weeks = 16,
  int seed = 42,
}) => _DemoGenerator(now: now, weeks: weeks, random: Random(seed)).build();

/// Progression of one exercise: [start] → [end] over the whole period.
/// weight_reps: weight in kg · bodyweight: reps · timed: seconds.
final class _Spec {
  const _Spec(
    this.name,
    this.type,
    this.category, {
    required this.start,
    required this.end,
    this.increment = 2.5,
    this.restSec,
    this.notes = '',
    this.archived = false,
  });

  final String name;
  final ExerciseType type;
  final ExerciseCategory category;
  final double start;
  final double end;
  final double increment;
  final int? restSec;
  final String notes;
  final bool archived;
}

const _specs = [
  _Spec(
    'Bankdrücken',
    ExerciseType.weightReps,
    ExerciseCategory.chest,
    start: 50,
    end: 62.5,
  ),
  _Spec(
    'Kniebeuge',
    ExerciseType.weightReps,
    ExerciseCategory.legs,
    start: 60,
    end: 77.5,
    restSec: 150,
  ),
  _Spec(
    'Kreuzheben',
    ExerciseType.weightReps,
    ExerciseCategory.back,
    start: 80,
    end: 97.5,
    restSec: 180,
  ),
  _Spec(
    'Schulterdrücken',
    ExerciseType.weightReps,
    ExerciseCategory.shoulders,
    start: 30,
    end: 36,
    increment: 2,
  ),
  _Spec(
    'Rudern am Kabel',
    ExerciseType.weightReps,
    ExerciseCategory.back,
    start: 45,
    end: 57.5,
    notes: 'Sitzhöhe 4, Griff eng',
  ),
  _Spec(
    'Latzug',
    ExerciseType.weightReps,
    ExerciseCategory.back,
    start: 50,
    end: 60,
  ),
  _Spec(
    'Beinpresse',
    ExerciseType.weightReps,
    ExerciseCategory.legs,
    start: 100,
    end: 135,
    increment: 5,
    notes: 'Rückenlehne Stufe 3',
  ),
  _Spec(
    'Bizepscurls',
    ExerciseType.weightReps,
    ExerciseCategory.arms,
    start: 12,
    end: 16,
    increment: 1,
  ),
  _Spec(
    'Klimmzüge',
    ExerciseType.bodyweight,
    ExerciseCategory.back,
    start: 5,
    end: 9,
    restSec: 120,
  ),
  _Spec(
    'Dips',
    ExerciseType.bodyweight,
    ExerciseCategory.chest,
    start: 8,
    end: 12,
  ),
  _Spec(
    'Plank',
    ExerciseType.timed,
    ExerciseCategory.core,
    start: 45,
    end: 90,
    restSec: 60,
  ),
  _Spec(
    'Wandsitzen',
    ExerciseType.timed,
    ExerciseCategory.legs,
    start: 40,
    end: 70,
    restSec: 60,
  ),
  _Spec(
    'Butterfly',
    ExerciseType.weightReps,
    ExerciseCategory.chest,
    start: 35,
    end: 40,
    archived: true,
  ),
];

/// Plan exercises: (exercise name, sets, reps, duration).
const _plans = <String, List<(String, int, int?, int?)>>{
  'Oberkörper': [
    ('Bankdrücken', 3, 8, null),
    ('Klimmzüge', 3, 8, null),
    ('Schulterdrücken', 3, 10, null),
    ('Rudern am Kabel', 3, 10, null),
    ('Dips', 3, 10, null),
    ('Bizepscurls', 3, 12, null),
  ],
  'Unterkörper': [
    ('Kniebeuge', 3, 8, null),
    ('Kreuzheben', 3, 5, null),
    ('Beinpresse', 3, 10, null),
    ('Plank', 3, null, 60),
    ('Wandsitzen', 2, null, 45),
  ],
};

const _sessionNotes = [
  'Gut geschlafen, viel Energie.',
  'Studio sehr voll.',
  'Schulter etwas gezwickt.',
  'Kurz vor Feierabend, wenig Zeit.',
];

final class _DemoGenerator {
  _DemoGenerator({required this.now, required this.weeks, required this.random})
    : assert(weeks >= 1);

  final DateTime now;
  final int weeks;
  final Random random;

  final _exercises = <Exercise>[];
  final _plansOut = <Plan>[];
  final _planExercises = <PlanExercise>[];
  final _sessions = <Session>[];
  final _sessionExercises = <SessionExercise>[];
  final _sets = <SetEntry>[];
  final _bodyWeights = <BodyWeightEntry>[];

  late final LocalDate _today = LocalDate.fromDateTime(now);
  late final LocalDate _firstMonday = _today
      .addDays(1 - _today.weekday)
      .addDays(-7 * (weeks - 1));
  late final int _totalDays = _today.differenceInDays(_firstMonday) + 1;

  Dataset build() {
    final created = storageTime(
      _firstMonday.addDays(-1).toLocalDateTime().add(const Duration(hours: 20)),
    );
    for (final spec in _specs) {
      _exercises.add(
        Exercise(
          id: _exercises.length + 1,
          name: spec.name,
          type: spec.type,
          category: spec.category,
          incrementKg: spec.increment,
          restSec: spec.restSec,
          includeInStrengthIndex: spec.type != ExerciseType.timed,
          notes: spec.notes,
          archived: spec.archived,
          createdAt: created,
        ),
      );
    }
    for (final MapEntry(key: name, value: entries) in _plans.entries) {
      final plan = Plan(
        id: _plansOut.length + 1,
        name: name,
        position: _plansOut.length,
        createdAt: created,
      );
      _plansOut.add(plan);
      for (final (i, (exerciseName, sets, reps, duration)) in entries.indexed) {
        _planExercises.add(
          PlanExercise(
            id: _planExercises.length + 1,
            planId: plan.id,
            exerciseId: _exerciseByName(exerciseName).id,
            position: i,
            targetSets: sets,
            targetReps: reps,
            targetDurationSec: duration,
            restSec: null,
          ),
        );
      }
    }

    _generateSessions();
    _generateBodyWeights();

    return Dataset(
      exercises: _exercises,
      plans: _plansOut,
      planExercises: _planExercises,
      sessions: _sessions,
      sessionExercises: _sessionExercises,
      sets: _sets,
      bodyWeights: _bodyWeights,
    );
  }

  Exercise _exerciseByName(String name) =>
      _exercises.firstWhere((e) => e.name == name);

  Set<int> _skippedWeeks() {
    if (weeks < 6) return {};
    final skipped = <int>{};
    while (skipped.length < 2) {
      skipped.add(2 + random.nextInt(weeks - 4));
    }
    return skipped;
  }

  void _generateSessions() {
    final skipped = _skippedWeeks();
    var nextPlan = 0;
    for (var week = 0; week < weeks; week++) {
      if (skipped.contains(week)) continue;
      final count = const [2, 3, 3, 3, 4][random.nextInt(5)];
      final days = _pickDays(week, count);
      for (final day in days) {
        final start = day.toLocalDateTime().add(
          Duration(hours: 17 + random.nextInt(3), minutes: random.nextInt(60)),
        );
        // Only sessions that are completely in the past.
        if (start.add(const Duration(hours: 2)).isAfter(now)) continue;
        final free = random.nextDouble() < 0.2;
        if (free) {
          _addSession(start, day, plan: null);
        } else {
          _addSession(start, day, plan: _plansOut[nextPlan % _plansOut.length]);
          nextPlan++;
        }
      }
    }
  }

  List<LocalDate> _pickDays(int week, int count) {
    final monday = _firstMonday.addDays(7 * week);
    final offsets = [0, 1, 2, 3, 4, 5, 6]..shuffle(random);
    final picked = offsets.take(count).toList()..sort();
    return [for (final o in picked) monday.addDays(o)];
  }

  /// Progress through the whole period, 0 … 1.
  double _progress(LocalDate day) =>
      (day.differenceInDays(_firstMonday) / _totalDays).clamp(0.0, 1.0);

  double _noise(double amplitude) =>
      (random.nextDouble() + random.nextDouble() - 1) * amplitude;

  void _addSession(DateTime localStart, LocalDate day, {required Plan? plan}) {
    final sessionId = _sessions.length + 1;
    final progress = _progress(day);

    final List<(Exercise, int, int?, int?, int?)> exercises;
    if (plan != null) {
      exercises = [
        for (final p in _planExercises.where((p) => p.planId == plan.id))
          (
            _exercises[p.exerciseId - 1],
            p.targetSets,
            p.targetReps,
            p.targetDurationSec,
            p.restSec,
          ),
      ];
    } else {
      final pool =
          _exercises.where((e) => !e.archived || progress < 0.5).toList()
            ..shuffle(random);
      exercises = [
        for (final e in pool.take(3 + random.nextInt(2)))
          (
            e,
            3,
            e.type == ExerciseType.timed ? null : 10,
            e.type == ExerciseType.timed ? 45 : null,
            null,
          ),
      ];
    }

    var cursor = localStart.add(Duration(minutes: 5 + random.nextInt(6)));
    for (final (i, (exercise, targetSets, reps, duration, restSec))
        in exercises.indexed) {
      final skippedExercise = random.nextDouble() < 0.04;
      final sessionExerciseId = _sessionExercises.length + 1;
      DateTime? completedAt;
      if (!skippedExercise) {
        final rest = restSec ?? exercise.restSec ?? 90;
        for (var setIndex = 1; setIndex <= targetSets; setIndex++) {
          cursor = cursor.add(Duration(seconds: 40 + random.nextInt(30)));
          _sets.add(
            _makeSet(
              id: _sets.length + 1,
              sessionExerciseId: sessionExerciseId,
              setIndex: setIndex,
              exercise: exercise,
              targetReps: reps,
              targetDuration: duration,
              progress: progress,
              completedAt: storageTime(cursor),
            ),
          );
          completedAt = storageTime(cursor);
          if (setIndex < targetSets) {
            cursor = cursor.add(Duration(seconds: rest + random.nextInt(40)));
          }
        }
      }
      _sessionExercises.add(
        SessionExercise(
          id: sessionExerciseId,
          sessionId: sessionId,
          exerciseId: exercise.id,
          position: i,
          targetSets: targetSets,
          targetReps: reps,
          targetDurationSec: duration,
          restSec: restSec,
          status: skippedExercise
              ? SessionExerciseStatus.skipped
              : SessionExerciseStatus.done,
          completedAt: completedAt,
        ),
      );
      cursor = cursor.add(Duration(minutes: 2 + random.nextInt(3)));
    }

    _sessions.add(
      Session(
        id: sessionId,
        planId: plan?.id,
        planNameSnapshot: plan?.name,
        startedAt: storageTime(localStart),
        endedAt: storageTime(
          cursor.add(Duration(minutes: 1 + random.nextInt(5))),
        ),
        notes: random.nextDouble() < 0.1
            ? _sessionNotes[random.nextInt(_sessionNotes.length)]
            : '',
      ),
    );
  }

  SetEntry _makeSet({
    required int id,
    required int sessionExerciseId,
    required int setIndex,
    required Exercise exercise,
    required int? targetReps,
    required int? targetDuration,
    required double progress,
    required DateTime completedAt,
  }) {
    final spec = _specs.firstWhere((s) => s.name == exercise.name);
    final level = spec.start + (spec.end - spec.start) * progress;
    // Later sets are a bit harder.
    final fatigue = setIndex >= 3 && random.nextDouble() < 0.4 ? 1 : 0;
    double? weight;
    int? reps;
    int? duration;
    switch (exercise.type) {
      case ExerciseType.weightReps:
        final raw = level + _noise(exercise.incrementKg);
        weight = max(
          exercise.incrementKg,
          (raw / exercise.incrementKg).round() * exercise.incrementKg,
        );
        reps = max(
          1,
          (targetReps ?? 10) - fatigue - (random.nextDouble() < 0.1 ? 1 : 0),
        );
      case ExerciseType.bodyweight:
        reps = max(1, (level + _noise(1.5)).round() - fatigue);
        // Added weight once the reps are easy.
        weight = exercise.name == 'Dips' && progress > 0.75 ? 5.0 : 0.0;
      case ExerciseType.timed:
        final base = min(level, (targetDuration ?? 45) * 1.6);
        duration = max(5, ((base + _noise(8)) / 5).round() * 5 - fatigue * 5);
    }
    return SetEntry(
      id: id,
      sessionExerciseId: sessionExerciseId,
      setIndex: setIndex,
      weightKg: weight,
      reps: reps,
      durationSec: duration,
      isWarmup: false,
      completedAt: completedAt,
    );
  }

  void _generateBodyWeights() {
    for (var week = 0; week < weeks; week++) {
      final days = _pickDays(week, 3 + random.nextInt(3));
      for (final day in days) {
        if (day.isAfter(_today)) continue;
        final trend = 82.0 - 1.5 * _progress(day);
        final kg = ((trend + _noise(0.5)) * 10).round() / 10;
        _bodyWeights.add(
          BodyWeightEntry(
            id: _bodyWeights.length + 1,
            date: day,
            weightKg: kg,
            createdAt: storageTime(
              day.toLocalDateTime().add(const Duration(hours: 7, minutes: 30)),
            ),
          ),
        );
      }
    }
  }
}
