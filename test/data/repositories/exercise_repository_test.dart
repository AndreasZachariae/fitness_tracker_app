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
  late ExerciseRepository repo;
  late PlanRepository plans;
  late SessionRepository sessions;

  setUp(() {
    db = newTestDatabase();
    final clock = newTestClock();
    repo = ExerciseRepository(db, clock);
    plans = PlanRepository(db, clock);
    sessions = SessionRepository(db, clock);
  });
  tearDown(() => db.close());

  Future<int> create(
    String name, [
    ExerciseType type = ExerciseType.weightReps,
  ]) => repo.create(ExerciseDraft(name: name, type: type));

  test('create stores cleaned values and defaults', () async {
    final id = await repo.create(
      const ExerciseDraft(
        name: '  Rudern   am Kabel ',
        type: ExerciseType.weightReps,
        category: ExerciseCategory.back,
        notes: ' Sitzhöhe 4 ',
      ),
    );
    final e = (await repo.findById(id))!;
    expect(e.name, 'Rudern am Kabel');
    expect(e.notes, 'Sitzhöhe 4');
    expect(e.incrementKg, 2.5);
    expect(e.includeInStrengthIndex, isTrue);
    expect(e.archived, isFalse);
    expect(e.createdAt, testNow);
  });

  test('timed exercises are not in the strength index by default', () async {
    final id = await create('Plank', ExerciseType.timed);
    expect((await repo.findById(id))!.includeInStrengthIndex, isFalse);
  });

  test('names are unique ignoring case, umlauts and whitespace', () async {
    await create('Übung');
    for (final name in ['übung', 'ÜBUNG', '  Übung ']) {
      await expectLater(
        create(name),
        throwsA(isA<DuplicateNameException>()),
        reason: name,
      );
    }
  });

  test('archived exercises still block their name', () async {
    final id = await create('Butterfly');
    await sessions.start(
      exercises: [SessionExerciseDraft(exerciseId: id, targetSets: 3)],
    );
    expect(await repo.deleteOrArchive(id), ExerciseRemoval.archived);
    await expectLater(
      create('butterfly'),
      throwsA(isA<DuplicateNameException>()),
    );
  });

  test('invalid names and values are rejected', () async {
    await expectLater(create('   '), throwsA(isA<InvalidNameException>()));
    await expectLater(
      repo.create(
        const ExerciseDraft(
          name: 'X',
          type: ExerciseType.weightReps,
          incrementKg: 0,
        ),
      ),
      throwsA(isA<InvalidValueException>()),
    );
  });

  test('update renames, keeping its own name allowed', () async {
    final id = await create('Latzug');
    final other = await create('Dips');
    final e = (await repo.findById(id))!;
    await repo.update(e.copyWith(name: 'latzug', restSec: 120));
    expect((await repo.findById(id))!.name, 'latzug');
    expect((await repo.findById(id))!.restSec, 120);
    await expectLater(
      repo.update(e.copyWith(name: 'DIPS')),
      throwsA(isA<DuplicateNameException>()),
    );
    expect((await repo.findById(other))!.name, 'Dips');
  });

  test('unused exercise is deleted and removed from plans', () async {
    final id = await create('Beinpresse');
    final planId = await plans.create('Beine');
    await plans.addExercise(planId, id, targetSets: 3);
    expect(await repo.deleteOrArchive(id), ExerciseRemoval.deleted);
    expect(await repo.findById(id), isNull);
    expect(await plans.getEntries(planId), isEmpty);
  });

  test('exercise with history is archived, not deleted (SPEC §5)', () async {
    final id = await create('Kniebeuge');
    final planId = await plans.create('Beine');
    await plans.addExercise(planId, id, targetSets: 3);
    final sessionId = await sessions.start(
      exercises: [SessionExerciseDraft(exerciseId: id, targetSets: 3)],
    );
    final detail = (await sessions.watchDetails(sessionId).first).single;
    await sessions.addSet(detail.sessionExercise.id, weightKg: 80, reps: 5);
    await sessions.finish(sessionId);

    expect(await repo.deleteOrArchive(id), ExerciseRemoval.archived);
    final archived = (await repo.findById(id))!;
    expect(archived.archived, isTrue);
    expect(await plans.getEntries(planId), isEmpty);
    // History is untouched.
    final sets = (await sessions.watchDetails(sessionId).first).single.sets;
    expect(sets.single.weightKg, 80);

    expect(await repo.watchActive().first, isEmpty);
    expect((await repo.watchArchived().first).single.id, id);

    await repo.restore(id);
    expect((await repo.watchActive().first).single.id, id);
  });

  test('watchActive is sorted by name and updates live', () async {
    final values = await recordStream(
      repo.watchActive().map((l) => l.map((e) => e.name).toList()),
      () async {
        await create('Zug');
        await pumpEventQueue();
        await create('ärmel');
      },
    );
    expect(values, [
      <String>[],
      ['Zug'],
      ['ärmel', 'Zug'],
    ]);
  });

  test('missing exercise → NotFoundException', () async {
    await expectLater(
      repo.deleteOrArchive(42),
      throwsA(isA<NotFoundException>()),
    );
    await expectLater(repo.restore(42), throwsA(isA<NotFoundException>()));
  });
}
