import 'dart:math';

import '../../domain/models/models.dart';
import '../db/storage_time.dart';

/// Generates a realistic, deterministic demo dataset (DEV app only):
/// [weeks] weeks up to [now], two plans plus free trainings, 14 exercises of
/// all types (one archived), progression with noise, skipped weeks and body
/// weight 3–5 times per week with a slight downward trend. "Oberkörper" has a
/// superset and a rotation (M9).
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
    'Hammercurls',
    ExerciseType.weightReps,
    ExerciseCategory.arms,
    start: 12,
    end: 15,
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

/// Plan exercises: (exercise name, sets, reps, duration, group key).
/// Group keys: see [_groups].
const _plans = <String, List<(String, int, int?, int?, int?)>>{
  'Oberkörper': [
    ('Bankdrücken', 3, 8, null, null),
    ('Klimmzüge', 3, 8, null, null),
    ('Schulterdrücken', 3, 10, null, 1),
    ('Rudern am Kabel', 3, 10, null, 1),
    ('Dips', 3, 10, null, null),
    ('Bizepscurls', 3, 12, null, 2),
    ('Hammercurls', 3, 12, null, 2),
  ],
  'Unterkörper': [
    ('Kniebeuge', 3, 8, null, null),
    ('Kreuzheben', 3, 5, null, null),
    ('Beinpresse', 3, 10, null, null),
    ('Plank', 3, null, 60, null),
    ('Wandsitzen', 2, null, 45, null),
  ],
};

/// Groups of "Oberkörper" by key: (kind, rest after a round).
const _groups = <int, (PlanGroupKind, int?)>{
  1: (PlanGroupKind.superset, 90),
  2: (PlanGroupKind.rotation, null),
};

/// An exercise of a generated session with its targets.
final class _Item {
  /// An exercise of a free training.
  const _Item(this.exercise, {required this.sets, this.reps, this.duration})
    : restSec = null,
      superset = null,
      rotation = null;

  _Item.of(this.exercise, PlanExercise p, {this.superset, this.rotation})
    : sets = p.targetSets,
      reps = p.targetReps,
      duration = p.targetDurationSec,
      restSec = p.restSec;

  final Exercise exercise;
  final int sets;
  final int? reps;
  final int? duration;
  final int? restSec;

  /// Plan group id of the superset this exercise belongs to.
  final int? superset;

  /// Plan group id of the rotation this exercise was chosen from.
  final int? rotation;
}

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
  final _planGroups = <PlanGroup>[];
  final _planSchedules = <PlanScheduleEntry>[];
  final _sessions = <Session>[];
  final _sessionExercises = <SessionExercise>[];
  final _sessionSupersets = <SessionSuperset>[];

  /// Rotation progress per plan group id: index of the due member.
  final _rotation = <int, int>{};
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
      // Training days (1.2.0): the first plan Mon/Thu 18:00, the second
      // Tue/Fri 18:30; further plans none.
      final days = switch (plan.id) {
        1 => {DateTime.monday: 18 * 60, DateTime.thursday: 18 * 60},
        2 => {DateTime.tuesday: 18 * 60 + 30, DateTime.friday: 18 * 60 + 30},
        _ => const <int, int>{},
      };
      for (final MapEntry(key: weekday, value: minute) in days.entries) {
        _planSchedules.add(
          PlanScheduleEntry(
            id: _planSchedules.length + 1,
            planId: plan.id,
            weekday: weekday,
            minuteOfDay: minute,
          ),
        );
      }
      final groupIds = <int, int>{};
      for (final (i, (exerciseName, sets, reps, duration, key))
          in entries.indexed) {
        int? groupId;
        if (key != null) {
          groupId = groupIds[key] ??= _addGroup(plan.id, key);
        }
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
            groupId: groupId,
          ),
        );
      }
    }

    _generateSessions();
    _generateBodyWeights();

    // The rotation remembers which exercise is due next.
    for (final (i, g) in _planGroups.indexed) {
      if (g.kind != PlanGroupKind.rotation) continue;
      final members = _members(g.id);
      _planGroups[i] = g.copyWith(
        rotationExerciseId:
            members[(_rotation[g.id] ?? 0) % members.length].exerciseId,
      );
    }

    return Dataset(
      exercises: _exercises,
      plans: _plansOut,
      planExercises: _planExercises,
      planGroups: _planGroups,
      planSchedules: _planSchedules,
      sessions: _sessions,
      sessionExercises: _sessionExercises,
      sessionSupersets: _sessionSupersets,
      sets: _sets,
      bodyWeights: _bodyWeights,
    );
  }

  int _addGroup(int planId, int key) {
    final (kind, rest) = _groups[key]!;
    final id = _planGroups.length + 1;
    _planGroups.add(
      PlanGroup(
        id: id,
        planId: planId,
        kind: kind,
        restSec: rest,
        rotationEvery: 1,
        rotationExerciseId: null,
        rotationDone: 0,
      ),
    );
    return id;
  }

  List<PlanExercise> _members(int groupId) => [
    for (final p in _planExercises)
      if (p.groupId == groupId) p,
  ];

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

    final List<_Item> exercises;
    if (plan != null) {
      exercises = [];
      final rotations = <int>{};
      for (final p in _planExercises.where((p) => p.planId == plan.id)) {
        final group = p.groupId == null ? null : _planGroups[p.groupId! - 1];
        if (group != null && group.kind == PlanGroupKind.rotation) {
          // Only the due member of a rotation.
          if (!rotations.add(group.id)) continue;
          final members = _members(group.id);
          final due = members[(_rotation[group.id] ?? 0) % members.length];
          exercises.add(
            _Item.of(_exercises[due.exerciseId - 1], due, rotation: group.id),
          );
          continue;
        }
        exercises.add(
          _Item.of(_exercises[p.exerciseId - 1], p, superset: group?.id),
        );
      }
    } else {
      final pool =
          _exercises.where((e) => !e.archived || progress < 0.5).toList()
            ..shuffle(random);
      exercises = [
        for (final e in pool.take(3 + random.nextInt(2)))
          _Item(
            e,
            sets: 3,
            reps: e.type == ExerciseType.timed ? null : 10,
            duration: e.type == ExerciseType.timed ? 45 : null,
          ),
      ];
    }

    var cursor = localStart.add(Duration(minutes: 5 + random.nextInt(6)));
    var i = 0;
    while (i < exercises.length) {
      final key = exercises[i].superset;
      if (key != null) {
        // A superset: all members alternately, rest after each round.
        final members = [
          for (
            var j = i;
            j < exercises.length && exercises[j].superset == key;
            j++
          )
            exercises[j],
        ];
        final supersetId = _sessionSupersets.length + 1;
        _sessionSupersets.add(
          SessionSuperset(
            id: supersetId,
            sessionId: sessionId,
            restSec: _planGroups[key - 1].restSec,
          ),
        );
        cursor = _addSupersetSets(
          sessionId,
          supersetId,
          i,
          members,
          cursor,
          progress,
        );
        i += members.length;
        continue;
      }
      final item = exercises[i];
      final exercise = item.exercise;
      final skippedExercise = random.nextDouble() < 0.04;
      final sessionExerciseId = _sessionExercises.length + 1;
      DateTime? completedAt;
      if (!skippedExercise) {
        final rest = item.restSec ?? exercise.restSec ?? 90;
        for (var setIndex = 1; setIndex <= item.sets; setIndex++) {
          cursor = cursor.add(Duration(seconds: 40 + random.nextInt(30)));
          _sets.add(
            _makeSet(
              id: _sets.length + 1,
              sessionExerciseId: sessionExerciseId,
              setIndex: setIndex,
              exercise: exercise,
              targetReps: item.reps,
              targetDuration: item.duration,
              progress: progress,
              completedAt: storageTime(cursor),
            ),
          );
          completedAt = storageTime(cursor);
          if (setIndex < item.sets) {
            cursor = cursor.add(Duration(seconds: rest + random.nextInt(40)));
          }
        }
        // The rotation moves on only when its exercise was trained.
        if (item.rotation case final r?) _rotation[r] = (_rotation[r] ?? 0) + 1;
      }
      _sessionExercises.add(
        SessionExercise(
          id: sessionExerciseId,
          sessionId: sessionId,
          exerciseId: exercise.id,
          position: i,
          targetSets: item.sets,
          targetReps: item.reps,
          targetDurationSec: item.duration,
          restSec: item.restSec,
          status: skippedExercise
              ? SessionExerciseStatus.skipped
              : SessionExerciseStatus.done,
          completedAt: completedAt,
        ),
      );
      cursor = cursor.add(Duration(minutes: 2 + random.nextInt(3)));
      i++;
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

  /// Sets of a superset: A1 B1 · rest · A2 B2 · rest … Returns the time
  /// after the superset.
  DateTime _addSupersetSets(
    int sessionId,
    int supersetId,
    int firstPosition,
    List<_Item> members,
    DateTime start,
    double progress,
  ) {
    var cursor = start;
    final ids = [
      for (var k = 0; k < members.length; k++) _sessionExercises.length + 1 + k,
    ];
    final completed = <int, DateTime>{};
    final rounds = members.map((m) => m.sets).reduce(max);
    final rest = _sessionSupersets[supersetId - 1].restSec ?? 90;
    for (var round = 1; round <= rounds; round++) {
      for (final (k, m) in members.indexed) {
        if (round > m.sets) continue;
        cursor = cursor.add(Duration(seconds: 40 + random.nextInt(30)));
        _sets.add(
          _makeSet(
            id: _sets.length + 1,
            sessionExerciseId: ids[k],
            setIndex: round,
            exercise: m.exercise,
            targetReps: m.reps,
            targetDuration: m.duration,
            progress: progress,
            completedAt: storageTime(cursor),
          ),
        );
        completed[k] = storageTime(cursor);
        // Changing stations within a round.
        cursor = cursor.add(Duration(seconds: 15 + random.nextInt(20)));
      }
      if (round < rounds) {
        cursor = cursor.add(Duration(seconds: rest + random.nextInt(40)));
      }
    }
    for (final (k, m) in members.indexed) {
      _sessionExercises.add(
        SessionExercise(
          id: ids[k],
          sessionId: sessionId,
          exerciseId: m.exercise.id,
          position: firstPosition + k,
          targetSets: m.sets,
          targetReps: m.reps,
          targetDurationSec: m.duration,
          restSec: m.restSec,
          status: SessionExerciseStatus.done,
          completedAt: completed[k],
          supersetId: supersetId,
        ),
      );
    }
    return cursor.add(Duration(minutes: 2 + random.nextInt(3)));
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
