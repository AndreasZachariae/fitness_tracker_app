import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/exercise_repository.dart';
import 'package:gymlog/data/repositories/plan_repository.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/streams.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late PlanRepository repo;
  late ExerciseRepository exercises;
  late SessionRepository sessions;
  late int bench;
  late int squat;
  late int plank;

  setUp(() async {
    db = newTestDatabase();
    final clock = newTestClock();
    repo = PlanRepository(db, clock);
    exercises = ExerciseRepository(db, clock);
    sessions = SessionRepository(db, clock);
    bench = await exercises.create(
      const ExerciseDraft(name: 'Bankdrücken', type: ExerciseType.weightReps),
    );
    squat = await exercises.create(
      const ExerciseDraft(name: 'Kniebeuge', type: ExerciseType.weightReps),
    );
    plank = await exercises.create(
      const ExerciseDraft(name: 'Plank', type: ExerciseType.timed),
    );
  });
  tearDown(() => db.close());

  List<String> names(List<Plan> plans) => [for (final p in plans) p.name];

  test('new plans are appended in chip order', () async {
    await repo.create('A');
    await repo.create('B');
    expect(names(await repo.getPlans()), ['A', 'B']);
    expect((await repo.getPlans()).map((p) => p.position), [0, 1]);
  });

  test('plan names are unique and validated', () async {
    final id = await repo.create('Oberkörper');
    await expectLater(
      repo.create('OBERKÖRPER'),
      throwsA(isA<DuplicateNameException>()),
    );
    await expectLater(repo.create(' '), throwsA(isA<InvalidNameException>()));
    await repo.rename(id, 'oberkörper');
    expect((await repo.findById(id))!.name, 'oberkörper');
  });

  test('entries with targets, duplicates rejected', () async {
    final planId = await repo.create('Ganzkörper');
    await repo.addExercise(planId, bench, targetSets: 3, targetReps: 10);
    await repo.addExercise(planId, plank, targetSets: 3, targetDurationSec: 45);
    await expectLater(
      repo.addExercise(planId, bench, targetSets: 3),
      throwsA(isA<DuplicateExerciseException>()),
    );
    final entries = await repo.getEntries(planId);
    expect(entries.map((e) => e.exercise.name), ['Bankdrücken', 'Plank']);
    expect(entries.first.planExercise.targetReps, 10);
    expect(entries.last.planExercise.targetDurationSec, 45);
  });

  test('target sets must be 1–10', () async {
    final planId = await repo.create('P');
    for (final sets in [0, 11]) {
      await expectLater(
        repo.addExercise(planId, bench, targetSets: sets),
        throwsA(isA<InvalidValueException>()),
      );
    }
    final id = await repo.addExercise(planId, bench, targetSets: 10);
    final entry = (await repo.getEntries(planId)).single.planExercise;
    expect(entry.id, id);
    await expectLater(
      repo.updateEntry(entry.copyWith(targetSets: 0)),
      throwsA(isA<InvalidValueException>()),
    );
    await repo.updateEntry(entry.copyWith(targetSets: 4, restSec: 120));
    final updated = (await repo.getEntries(planId)).single.planExercise;
    expect((updated.targetSets, updated.restSec), (4, 120));
  });

  test('reorder plans and entries; partial orders are rejected', () async {
    final a = await repo.create('A');
    final b = await repo.create('B');
    await repo.reorder([b, a]);
    expect(names(await repo.getPlans()), ['B', 'A']);
    await expectLater(repo.reorder([b]), throwsA(isA<InvalidValueException>()));

    final e1 = await repo.addExercise(a, bench, targetSets: 3);
    final e2 = await repo.addExercise(a, squat, targetSets: 3);
    final e3 = await repo.addExercise(a, plank, targetSets: 3);
    await repo.reorderEntries(a, [e3, e1, e2]);
    expect((await repo.getEntries(a)).map((e) => e.exercise.name), [
      'Plank',
      'Bankdrücken',
      'Kniebeuge',
    ]);
    await expectLater(
      repo.reorderEntries(a, [e1, e1, e2]),
      throwsA(isA<InvalidValueException>()),
    );
  });

  test('removeEntry returns the removed entry', () async {
    final planId = await repo.create('P');
    final id = await repo.addExercise(planId, bench, targetSets: 3);
    final removed = await repo.removeEntry(id);
    expect(removed.exerciseId, bench);
    expect(await repo.getEntries(planId), isEmpty);
  });

  test('duplicate copies all entries with their targets', () async {
    final planId = await repo.create('Push');
    await repo.addExercise(planId, bench, targetSets: 4, targetReps: 6);
    await repo.addExercise(planId, plank, targetSets: 2, targetDurationSec: 60);
    final copyId = await repo.duplicate(planId, 'Push (Kopie)');
    final copy = await repo.getEntries(copyId);
    expect(copy.map((e) => e.exercise.name), ['Bankdrücken', 'Plank']);
    expect(copy.first.planExercise.targetSets, 4);
    expect(copy.last.planExercise.targetDurationSec, 60);
    expect(names(await repo.getPlans()), ['Push', 'Push (Kopie)']);
  });

  test('deleting a plan keeps the history (snapshot name)', () async {
    final planId = await repo.create('Push');
    await repo.addExercise(planId, bench, targetSets: 3);
    final plan = (await repo.findById(planId))!;
    final sessionId = await sessions.start(
      plan: plan,
      exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 3)],
    );
    await sessions.finish(sessionId);

    await repo.delete(planId);
    expect(await repo.getPlans(), isEmpty);
    final session = (await sessions.findById(sessionId))!;
    expect(session.planId, isNull);
    expect(session.planNameSnapshot, 'Push');
    expect((await sessions.watchDetails(sessionId).first), hasLength(1));
  });

  test('watchEntries updates live', () async {
    final planId = await repo.create('P');
    final values = await recordStream(
      repo
          .watchEntries(planId)
          .map((l) => l.map((e) => e.exercise.name).toList()),
      () => repo.addExercise(planId, plank, targetSets: 3),
    );
    expect(values, [
      <String>[],
      ['Plank'],
    ]);
  });
}
