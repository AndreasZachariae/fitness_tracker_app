import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/io/fitnotes_import_service.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/domain/fitnotes_import.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// 1.4.0: FitNotes import into the database.
void main() {
  final workout = parseFitNotes(
    File('test/fixtures/fitnotes_workout.txt').readAsStringSync(),
  );
  int indexOf(String name) =>
      workout.exercises.indexWhere((e) => e.name == name);

  late AppDatabase db;
  late Repos r;
  late FitNotesImportService service;
  late int bench;
  late int ringWeights;

  setUp(() async {
    db = newTestDatabase();
    r = Repos(db);
    service = FitNotesImportService(db: db, clock: newTestClock());
    bench = await addExercise(r, 'Bankdrücken');
    // Same name as in the file, but another type.
    ringWeights = await addExercise(r, 'Ring Push Up');
  });
  tearDown(() => db.close());

  List<int?> targets({Map<String, int> mapped = const {}}) => [
    for (final e in workout.exercises) mapped[e.name],
  ];

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  test('plan with targets and groups, the training on its day', () async {
    final result = await service.import(
      workout,
      planName: 'Montag',
      targets: targets(mapped: {'Flat Barbell Bench Press': bench}),
      withTraining: true,
    );
    expect(result.newExercises, 14);

    // Exercises: the chosen one, the others new with type and category.
    final all = await db.exercisesDao.getAll();
    Exercise named(String n) => all.firstWhere((e) => e.name == n);
    expect(named('Isometric Neutral Pull Up').type, ExerciseType.timed);
    expect(named('Isometric Neutral Pull Up').category, ExerciseCategory.back);
    expect(named('Reverse Crunches').type, ExerciseType.bodyweight);
    expect(named('Ring Push Up (FitNotes)').type, ExerciseType.bodyweight);
    expect(named('Ring Push Up').id, ringWeights, reason: 'left alone');

    // Plan: all exercises with their targets.
    final plan = (await r.plans.findById(result.planId))!;
    expect(plan.name, 'Montag');
    final entries = await r.plans.getEntries(plan.id);
    expect(entries, hasLength(15));
    PlanExercise entry(String n) =>
        entries.firstWhere((e) => e.exercise.name == n).planExercise;
    expect(entry('Bankdrücken').targetSets, 3);
    expect(entry('Bankdrücken').targetReps, 12);
    expect(entry('One Arm Row Lat Machine').targetSets, 5);
    expect(entry('Isometric Neutral Pull Up').targetDurationSec, 30);

    // Groups: three rotations ("Rotate"), one superset ("Core Set").
    final groups = await r.plans.getGroups(plan.id);
    final kinds = [for (final g in groups.values) g.kind];
    expect(kinds.where((k) => k == PlanGroupKind.rotation), hasLength(3));
    expect(kinds.where((k) => k == PlanGroupKind.superset), hasLength(1));
    final superset = groups.values.firstWhere(
      (g) => g.kind == PlanGroupKind.superset,
    );
    expect(
      [
        for (final e in entries)
          if (e.planExercise.groupId == superset.id) e.exercise.name,
      ],
      ['Back Extensions (Rolling)', 'Cable Crunch', 'Reverse Crunches'],
    );
    expect(entry('Ring Push Up (FitNotes)').groupId, isNull);

    // The training: finished, on 2.11. evening, all 47 sets with weights.
    final session = (await r.sessions.findById(result.sessionId!))!;
    expect(session.planId, plan.id);
    expect(session.planNameSnapshot, 'Montag');
    final start = session.startedAt.toLocal();
    expect((start.year, start.month, start.day, start.hour), (2026, 11, 2, 18));
    expect(session.endedAt, isNotNull);
    final details = await r.sessions.getDetails(session.id);
    expect(details.fold<int>(0, (n, d) => n + d.sets.length), 47);
    final benchSets = details.first.sets;
    expect(benchSets.map((s) => (s.weightKg, s.reps)), [
      (52.5, 12),
      (52.5, 12),
      (52.5, 9),
    ]);
    final hold = details.firstWhere(
      (d) => d.exercise.name == 'Isometric Neutral Pull Up',
    );
    expect(hold.sets.map((s) => s.durationSec), [30, 30, 25]);
    // The supersets of the training as in the plan.
    expect(await count('session_supersets'), 1);

    // "Letztes Mal" knows the weights now.
    final last = await r.sessions.watchLastPerformances().first;
    expect(last[bench]!.sets.first.weightKg, 52.5);

    // The trained exercise of a rotation moves it on, as after a training.
    final chest = groups.values.firstWhere(
      (g) => g.rotationExerciseId == bench,
      orElse: () => groups.values.first,
    );
    final after = await r.plans.getGroups(plan.id);
    expect(
      after[chest.id]!.rotationExerciseId,
      isNot(bench),
      reason: 'Bankdrücken was trained, the flys are next',
    );
  });

  test('only the plan: no training', () async {
    final result = await service.import(
      workout,
      planName: 'Montag',
      targets: targets(),
      withTraining: false,
    );
    expect(result.sessionId, isNull);
    expect(await count('sessions'), 0);
    expect(await r.plans.getEntries(result.planId), hasLength(15));
    expect(result.newExercises, 15);
  });

  test('errors store nothing', () async {
    final exercisesBefore = await count('exercises');
    // The sets do not fit: reps only into a weight × reps exercise.
    await expectLater(
      service.import(
        workout,
        planName: 'Montag',
        targets: targets(mapped: {'Ring Push Up': ringWeights}),
        withTraining: true,
      ),
      throwsA(isA<InvalidValueException>()),
    );
    // A running training blocks the training import.
    await r.sessions.start(
      exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 1)],
    );
    await expectLater(
      service.import(
        workout,
        planName: 'Montag',
        targets: targets(),
        withTraining: true,
      ),
      throwsA(isA<ActiveSessionExistsException>()),
    );
    expect(await count('plans'), 0);
    expect(await count('exercises'), exercisesBefore);
    expect(await count('sessions'), 1, reason: 'only the running one');
    // The same exercise for two lines is refused up front.
    expect(
      () => service.import(
        workout,
        planName: 'Montag',
        targets: [
          for (final (i, _) in workout.exercises.indexed)
            i == indexOf('Hip Thrust') || i == 0 ? bench : null,
        ],
        withTraining: false,
      ),
      throwsArgumentError,
    );
  });

  test('a training of today ends now at the latest', () async {
    // 11:00 local: 18:00 would still be ahead.
    final morning = DateTime.utc(2026, 11, 3, 10);
    final early = FitNotesImportService(db: db, clock: FixedClock(morning));
    final today = parseFitNotes(
      'FitNotes Workout - Dienstag 3rd November 2026\n** A **\n- 5 reps\n'
      '- 5 reps\n',
    );
    final result = await early.import(
      today,
      planName: 'Heute',
      targets: [null],
      withTraining: true,
    );
    final session = (await r.sessions.findById(result.sessionId!))!;
    expect(session.endedAt, morning);
    expect(
      session.startedAt,
      morning.subtract(FitNotesImportService.setSpacing * 2),
    );
  });

  test('names of new exercises', () {
    final taken = {'ring push up', 'ring push up (fitnotes)'};
    expect(uniqueImportName('Squat  Deep', taken), 'Squat Deep');
    expect(
      uniqueImportName('Ring Push Up', taken),
      'Ring Push Up (FitNotes 2)',
    );
    final long = 'X' * 70;
    expect(uniqueImportName(long, {}).length, 60);
    expect(uniqueImportName(long, {'x' * 60}), endsWith(' (FitNotes)'));
    expect(uniqueImportName(long, {'x' * 60}).length, 60);
  });

  test('groups need two exercises', () {
    final w = parseFitNotes('''
FitNotes Workout - 1st June 2026
** A ** (Leg Set)
- 5 reps
** B ** (Arm Rotate)
- 5 reps
** C ** (Arm Rotate)
- 5 reps
** D ** (just a note)
- 5 reps
''');
    final groups = importGroups(w);
    expect(groups, hasLength(1));
    expect(groups.single.kind, PlanGroupKind.rotation);
    expect(groups.single.members, [1, 2]);
  });
}
