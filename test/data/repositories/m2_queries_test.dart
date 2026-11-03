import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/exercise_repository.dart';
import 'package:gymlog/data/repositories/plan_repository.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/test_db.dart';

/// Queries and rules added for M2 (exercise and plan screens).
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ExerciseRepository exercises;
  late PlanRepository plans;
  late SessionRepository sessions;
  late int bench;
  late int squat;

  setUp(() async {
    db = newTestDatabase();
    clock = newTestClock();
    exercises = ExerciseRepository(db, clock);
    plans = PlanRepository(db, clock);
    sessions = SessionRepository(db, clock);
    bench = await exercises.create(
      const ExerciseDraft(name: 'Bankdrücken', type: ExerciseType.weightReps),
    );
    squat = await exercises.create(
      const ExerciseDraft(name: 'Kniebeuge', type: ExerciseType.weightReps),
    );
  });
  tearDown(() => db.close());

  /// A session with the given sets per exercise ({exerciseId: [(kg, reps)]}).
  Future<int> session(
    Map<int, List<(double, int)>> sets, {
    bool finish = true,
  }) async {
    final id = await sessions.start(
      exercises: [
        for (final e in sets.keys)
          SessionExerciseDraft(exerciseId: e, targetSets: 3),
      ],
    );
    final details = await sessions.watchDetails(id).first;
    for (final d in details) {
      for (final (kg, reps) in sets[d.exercise.id]!) {
        await sessions.addSet(d.sessionExercise.id, weightKg: kg, reps: reps);
      }
    }
    if (finish) await sessions.finish(id);
    clock.advance(const Duration(days: 2));
    return id;
  }

  group('last performance', () {
    test(
      'uses the latest finished session with sets of the exercise',
      () async {
        await session({
          bench: [(60, 10), (60, 10), (60, 8)],
          squat: [(80, 5)],
        });
        await session({
          bench: [(62.5, 8)],
          squat: [],
        });
        final last = await sessions.watchLastPerformances().first;
        expect(last[bench]!.sets.map((s) => s.weightKg), [62.5]);
        // Squat had no set in the second session → first session counts.
        expect(last[squat]!.sets.map((s) => (s.weightKg, s.reps)), [(80.0, 5)]);
      },
    );

    test('ignores the running session', () async {
      await session({
        bench: [(60, 10)],
      });
      await session({
        bench: [(100, 1)],
      }, finish: false);
      final last = await sessions.watchLastPerformances().first;
      expect(last[bench]!.sets.single.weightKg, 60);
    });

    test('updates when a session is finished', () async {
      expect(await sessions.watchLastPerformances().first, isEmpty);
      await session({
        bench: [(60, 10)],
      });
      expect(
        (await sessions.watchLastPerformances().first)[bench]!.sets,
        hasLength(1),
      );
    });
  });

  test('recently used: newest session first, archived excluded', () async {
    final plank = await exercises.create(
      const ExerciseDraft(name: 'Plank', type: ExerciseType.timed),
    );
    await session({
      squat: [(80, 5)],
    });
    await session({
      bench: [(60, 10)],
    });
    expect((await exercises.watchRecentlyUsed().first).map((e) => e.id), [
      bench,
      squat,
    ]);
    await exercises.deleteOrArchive(bench);
    expect((await exercises.watchRecentlyUsed().first).map((e) => e.id), [
      squat,
    ]);
    expect(
      (await exercises.watchRecentlyUsed().first).map((e) => e.id),
      isNot(contains(plank)),
    );
  });

  test('type cannot change once the exercise has history', () async {
    final e = (await exercises.findById(squat))!;
    await exercises.update(e.copyWith(type: ExerciseType.bodyweight));
    await exercises.update(e.copyWith(type: ExerciseType.weightReps));
    await session({
      squat: [(80, 5)],
    });
    await expectLater(
      exercises.update(e.copyWith(type: ExerciseType.timed)),
      throwsA(isA<TypeChangeNotAllowedException>()),
    );
    // Other fields can still change.
    await exercises.update(e.copyWith(name: 'Back Squat'));
    expect((await exercises.findById(squat))!.name, 'Back Squat');
  });

  test('restoreEntry puts a removed plan exercise back in place', () async {
    final plank = await exercises.create(
      const ExerciseDraft(name: 'Plank', type: ExerciseType.timed),
    );
    final planId = await plans.create('Ganzkörper');
    await plans.addExercise(planId, bench, targetSets: 3, targetReps: 8);
    final middle = await plans.addExercise(
      planId,
      squat,
      targetSets: 4,
      targetReps: 5,
      restSec: 180,
    );
    await plans.addExercise(planId, plank, targetSets: 3);

    final removed = await plans.removeEntry(middle);
    await plans.restoreEntry(removed);
    final entries = await plans.getEntries(planId);
    expect(entries.map((e) => e.exercise.name), [
      'Bankdrücken',
      'Kniebeuge',
      'Plank',
    ]);
    expect(entries[1].planExercise, removed);
    await expectLater(
      plans.restoreEntry(removed),
      throwsA(isA<DuplicateExerciseException>()),
    );
  });

  test('entry counts and plan count per exercise', () async {
    final a = await plans.create('A');
    final b = await plans.create('B');
    await plans.addExercise(a, bench, targetSets: 3);
    await plans.addExercise(a, squat, targetSets: 3);
    await plans.addExercise(b, bench, targetSets: 3);
    expect(await plans.watchEntryCounts().first, {a: 2, b: 1});
    expect(await exercises.planCount(bench), 2);
    expect(await exercises.planCount(squat), 1);
  });
}
