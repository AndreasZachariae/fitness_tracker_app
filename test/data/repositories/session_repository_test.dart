import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/exercise_repository.dart';
import 'package:gymlog/data/repositories/plan_repository.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/set_validation.dart';

import '../../helpers/streams.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late SessionRepository repo;
  late int bench;
  late int pullUps;
  late int plank;

  setUp(() async {
    db = newTestDatabase();
    clock = newTestClock();
    repo = SessionRepository(db, clock);
    final exercises = ExerciseRepository(db, clock);
    bench = await exercises.create(
      const ExerciseDraft(name: 'Bankdrücken', type: ExerciseType.weightReps),
    );
    pullUps = await exercises.create(
      const ExerciseDraft(name: 'Klimmzüge', type: ExerciseType.bodyweight),
    );
    plank = await exercises.create(
      const ExerciseDraft(name: 'Plank', type: ExerciseType.timed),
    );
  });
  tearDown(() => db.close());

  Future<int> startAll() => repo.start(
    exercises: [
      SessionExerciseDraft(exerciseId: bench, targetSets: 3, targetReps: 10),
      SessionExerciseDraft(exerciseId: pullUps, targetSets: 3, targetReps: 8),
      SessionExerciseDraft(
        exerciseId: plank,
        targetSets: 2,
        targetDurationSec: 45,
      ),
    ],
  );

  Future<List<SessionExerciseDetail>> details(int sessionId) =>
      repo.watchDetails(sessionId).first;

  test('start copies the exercises, the first one is active', () async {
    final id = await startAll();
    final session = (await repo.getActive())!;
    expect(session.id, id);
    expect(session.startedAt, testNow);
    expect(session.isFreeTraining, isTrue);
    final d = await details(id);
    expect(d.map((e) => e.exercise.name), [
      'Bankdrücken',
      'Klimmzüge',
      'Plank',
    ]);
    expect(d.map((e) => e.sessionExercise.status), [
      SessionExerciseStatus.active,
      SessionExerciseStatus.pending,
      SessionExerciseStatus.pending,
    ]);
    expect(d.last.sessionExercise.targetDurationSec, 45);
  });

  test('a free training without exercises can be started', () async {
    final id = await repo.start(exercises: const []);
    expect(await details(id), isEmpty);
  });

  test('at most one active session', () async {
    final first = await startAll();
    await expectLater(
      startAll(),
      throwsA(
        isA<ActiveSessionExistsException>().having(
          (e) => e.activeSessionId,
          'activeSessionId',
          first,
        ),
      ),
    );
    await repo.finish(first);
    final second = await startAll();
    expect((await repo.getActive())!.id, second);
  });

  test('duplicate or unknown exercises are rejected on start', () async {
    await expectLater(
      repo.start(
        exercises: [
          SessionExerciseDraft(exerciseId: bench, targetSets: 3),
          SessionExerciseDraft(exerciseId: bench, targetSets: 3),
        ],
      ),
      throwsA(isA<DuplicateExerciseException>()),
    );
    await expectLater(
      repo.start(
        exercises: const [SessionExerciseDraft(exerciseId: 99, targetSets: 3)],
      ),
      throwsA(isA<NotFoundException>()),
    );
    expect(await repo.getActive(), isNull, reason: 'rolled back');
  });

  test(
    'sets are stored immediately with only the fields of the type',
    () async {
      final id = await startAll();
      final d = await details(id);
      clock.advance(const Duration(minutes: 3));

      final s1 = await repo.addSet(
        d[0].sessionExercise.id,
        weightKg: 62.5,
        reps: 10,
        durationSec: 30,
      );
      expect(
        (s1.setIndex, s1.weightKg, s1.reps, s1.durationSec),
        (1, 62.5, 10, null),
      );
      expect(s1.completedAt, testNow.add(const Duration(minutes: 3)));

      final s2 = await repo.addSet(d[1].sessionExercise.id, reps: 8);
      expect((s2.weightKg, s2.reps), (0.0, 8), reason: 'bodyweight default +0');

      final s3 = await repo.addSet(
        d[2].sessionExercise.id,
        durationSec: 45,
        reps: 5,
      );
      expect((s3.weightKg, s3.reps, s3.durationSec), (null, null, 45));

      // Visible right away, without finishing the session.
      final reloaded = await details(id);
      expect(reloaded.map((e) => e.sets.length), [1, 1, 1]);
    },
  );

  test('invalid sets are rejected with the reason', () async {
    final id = await startAll();
    final d = await details(id);
    await expectLater(
      repo.addSet(d[0].sessionExercise.id, reps: 10),
      throwsA(
        isA<InvalidSetException>().having(
          (e) => e.error,
          'error',
          SetValidationError.weightRequired,
        ),
      ),
    );
    await expectLater(
      repo.addSet(d[2].sessionExercise.id),
      throwsA(isA<InvalidSetException>()),
    );
    expect((await details(id)).expand((e) => e.sets), isEmpty);
  });

  test('no new sets in a finished session', () async {
    final id = await startAll();
    final d = await details(id);
    await repo.finish(id);
    await expectLater(
      repo.addSet(d[0].sessionExercise.id, weightKg: 60, reps: 10),
      throwsA(isA<SessionNotActiveException>()),
    );
    await expectLater(
      repo.finish(id),
      throwsA(isA<SessionNotActiveException>()),
    );
  });

  test('deleteSet renumbers the following sets', () async {
    final id = await startAll();
    final seId = (await details(id)).first.sessionExercise.id;
    final sets = [
      for (final reps in [10, 9, 8])
        await repo.addSet(seId, weightKg: 60, reps: reps),
    ];
    await repo.deleteSet(sets[1].id);
    final left = (await details(id)).first.sets;
    expect(left.map((s) => (s.setIndex, s.reps)), [(1, 10), (2, 8)]);
    final next = await repo.addSet(seId, weightKg: 60, reps: 7);
    expect(next.setIndex, 3);
  });

  test('delete removes the session with exercises and sets', () async {
    final id = await startAll();
    final seId = (await details(id)).first.sessionExercise.id;
    await repo.addSet(seId, weightKg: 60, reps: 10);
    await repo.delete(id);
    expect(await repo.findById(id), isNull);
    expect(await db.select(db.sessionExercises).get(), isEmpty);
    expect(await db.select(db.setEntries).get(), isEmpty);
    expect(await db.select(db.exercises).get(), hasLength(3));
  });

  group('restoreDeleted (1.0.1: "Rückgängig" in the history)', () {
    Future<int> finishedWithSuperset({int? planId}) async {
      final id = await repo.start(
        plan: planId == null
            ? null
            : (await PlanRepository(db, clock).findById(planId)),
        exercises: [
          SessionExerciseDraft(exerciseId: bench, targetSets: 2),
          SessionExerciseDraft(exerciseId: pullUps, targetSets: 2),
        ],
      );
      final d = await details(id);
      await repo.createSuperset(id, [for (final e in d) e.sessionExercise.id]);
      await repo.addSet(d[0].sessionExercise.id, weightKg: 60, reps: 10);
      await repo.addSet(d[1].sessionExercise.id, weightKg: 0, reps: 8);
      await repo.finishSession(id);
      return id;
    }

    test(
      'brings back session, exercises, superset and sets with ids',
      () async {
        final id = await finishedWithSuperset();
        Future<List<Object>> snapshot() async => [
          (await repo.findById(id))!,
          await db.select(db.sessionExercises).get(),
          await db.select(db.sessionSupersets).get(),
          await db.select(db.setEntries).get(),
        ];
        final before = await snapshot();
        final deleted = await repo.delete(id);
        expect(deleted.sets, hasLength(2));
        expect(deleted.supersets, hasLength(1));
        expect(await repo.findById(id), isNull);

        await repo.restoreDeleted(deleted);
        expect(await snapshot(), before);
      },
    );

    test('a plan deleted in the meantime is dropped, the name stays', () async {
      final plans = PlanRepository(db, clock);
      final planId = await plans.create('Push');
      await plans.addExercise(planId, bench, targetSets: 2);
      final id = await finishedWithSuperset(planId: planId);
      final deleted = await repo.delete(id);
      await plans.delete(planId);
      await repo.restoreDeleted(deleted);
      final s = (await repo.findById(id))!;
      expect(s.planId, isNull);
      expect(s.planNameSnapshot, 'Push');
    });
  });

  test('watchActive and watchFinished follow the session', () async {
    late int id;
    final finished = <List<int>>[];
    final active = await recordStream(
      repo.watchActive().map((s) => s?.id),
      () async {
        final sub = repo
            .watchFinished()
            .map((l) => l.map((s) => s.id).toList())
            .listen(finished.add);
        await pumpEventQueue();
        id = await startAll();
        await pumpEventQueue();
        clock.advance(const Duration(hours: 1));
        await repo.finish(id);
        await pumpEventQueue();
        await sub.cancel();
      },
    );
    expect(active, [null, id, null]);
    expect(finished.first, isEmpty);
    expect(finished.last, [id]);
    expect(
      (await repo.findById(id))!.endedAt,
      testNow.add(const Duration(hours: 1)),
    );
  });
}
