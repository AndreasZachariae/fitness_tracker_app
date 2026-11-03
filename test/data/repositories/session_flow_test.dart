import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/exercise_repository.dart';
import 'package:gymlog/data/repositories/plan_repository.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/records.dart';

import '../../helpers/test_db.dart';

const pending = SessionExerciseStatus.pending;
const active = SessionExerciseStatus.active;
const done = SessionExerciseStatus.done;
const skipped = SessionExerciseStatus.skipped;

/// Session actions of M3 (SPEC §6.2, §6.3).
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late SessionRepository repo;
  late PlanRepository plans;
  late int bench, squat, plank;

  setUp(() async {
    db = newTestDatabase();
    clock = newTestClock();
    repo = SessionRepository(db, clock);
    plans = PlanRepository(db, clock);
    final exercises = ExerciseRepository(db, clock);
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

  Future<int> startSession({int sets = 2, Plan? plan}) => repo.start(
    plan: plan,
    exercises: [
      SessionExerciseDraft(exerciseId: bench, targetSets: sets),
      SessionExerciseDraft(exerciseId: squat, targetSets: sets),
      SessionExerciseDraft(exerciseId: plank, targetSets: sets),
    ],
  );

  Future<List<SessionExerciseDetail>> details(int id) => repo.getDetails(id);

  Future<List<SessionExerciseStatus>> statuses(int id) async => [
    for (final d in await details(id)) d.sessionExercise.status,
  ];

  Future<int> seId(int sessionId, int index) async =>
      (await details(sessionId))[index].sessionExercise.id;

  const w60 = SetValues(weightKg: 60, reps: 10);

  test(
    'reaching the target marks the exercise done, nothing else active',
    () async {
      final id = await startSession();
      final first = await seId(id, 0);
      final s1 = await repo.saveSet(first, w60);
      expect(s1.completedExercise, isFalse);
      expect(await statuses(id), [active, pending, pending]);

      clock.advance(const Duration(minutes: 2));
      final s2 = await repo.saveSet(first, w60);
      expect(s2.completedExercise, isTrue);
      expect(await statuses(id), [done, pending, pending]);
      final d = (await details(id)).first.sessionExercise;
      expect(d.completedAt, s2.set.completedAt);
    },
  );

  test('with autoActivateNext the next open exercise becomes active', () async {
    await SettingsRepository(db)
        .update((s) => s.copyWith(autoActivateNext: true));
    final id = await startSession(sets: 1);
    await repo.saveSet(await seId(id, 0), w60);
    expect(await statuses(id), [done, active, pending]);
    await repo.skip(await seId(id, 1));
    expect(await statuses(id), [done, skipped, active]);
  });

  test('undo deletes the set and restores every status', () async {
    await SettingsRepository(db)
        .update((s) => s.copyWith(autoActivateNext: true));
    final id = await startSession(sets: 2);
    final first = await seId(id, 0);
    await repo.saveSet(first, w60);
    final saved = await repo.saveSet(first, w60);
    expect(await statuses(id), [done, active, pending]);

    await repo.undoSave(saved);
    expect(await statuses(id), [active, pending, pending]);
    final sets = (await details(id)).first.sets;
    expect(sets, hasLength(1));
    expect((await details(id)).first.sessionExercise.completedAt, isNull);
  });

  test('activating another exercise keeps the sets of the previous', () async {
    final id = await startSession();
    final first = await seId(id, 0);
    await repo.saveSet(first, w60);
    await repo.activate(await seId(id, 2));
    expect(await statuses(id), [pending, pending, active]);
    expect((await details(id)).first.sets, hasLength(1));
  });

  test('skip, finish exercise, reopen, +1 set', () async {
    final id = await startSession(sets: 3);
    final first = await seId(id, 0);
    await expectLater(
      repo.finishExercise(first),
      throwsA(isA<InvalidValueException>()),
      reason: 'needs at least one set',
    );
    await repo.saveSet(first, w60);
    await repo.finishExercise(first);
    expect(await statuses(id), [done, pending, pending]);

    await repo.skip(await seId(id, 1));
    expect(await statuses(id), [done, skipped, pending]);

    await repo.activate(first); // "Wieder öffnen"
    expect(await statuses(id), [active, skipped, pending]);
    await repo.addTargetSet(first);
    expect((await details(id)).first.sessionExercise.targetSets, 4);
  });

  test('saving into an open exercise makes it the active one', () async {
    final id = await startSession();
    await repo.saveSet(await seId(id, 1), w60);
    expect(await statuses(id), [pending, active, pending]);
  });

  test('exercises can be added to the session only', () async {
    final planId = await plans.create('Push');
    await plans.addExercise(planId, bench, targetSets: 3);
    final plan = (await plans.findById(planId))!;
    final id = await repo.start(
      plan: plan,
      exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 3)],
    );
    await repo.addExerciseToSession(
      id,
      plank,
      const ExerciseTargets(sets: 2, durationSec: 30),
    );
    final d = await details(id);
    expect(d.map((e) => e.exercise.name), ['Bankdrücken', 'Plank']);
    expect(d.last.sessionExercise.status, pending);
    expect(await plans.getEntries(planId), hasLength(1));
    await expectLater(
      repo.addExerciseToSession(id, plank, const ExerciseTargets(sets: 2)),
      throwsA(isA<DuplicateExerciseException>()),
    );
  });

  test('reorder keeps done and skipped exercises in place', () async {
    final id = await startSession(sets: 1);
    final ids = [for (final d in await details(id)) d.sessionExercise.id];
    await repo.saveSet(ids[0], w60); // done at position 0
    await repo.reorderSession(id, [ids[0], ids[2], ids[1]]);
    expect((await details(id)).map((d) => d.exercise.name), [
      'Bankdrücken',
      'Plank',
      'Kniebeuge',
    ]);
    await expectLater(
      repo.reorderSession(id, [ids[2], ids[0], ids[1]]),
      throwsA(isA<InvalidValueException>()),
    );
  });

  test('updateSet validates and keeps index and time', () async {
    final id = await startSession();
    final saved = await repo.saveSet(await seId(id, 0), w60);
    await repo.updateSet(
      saved.set.id,
      const SetValues(weightKg: 62.5, reps: 8, durationSec: 99),
    );
    final set = (await details(id)).first.sets.single;
    expect((set.weightKg, set.reps, set.durationSec), (62.5, 8, null));
    expect(set.completedAt, saved.set.completedAt);
    await expectLater(
      repo.updateSet(saved.set.id, const SetValues(reps: 8)),
      throwsA(isA<InvalidSetException>()),
    );
  });

  test('finishing: no sets → skipped, open with sets → done', () async {
    final id = await startSession(sets: 3);
    final ids = [for (final d in await details(id)) d.sessionExercise.id];
    await repo.saveSet(ids[0], w60); // active with 1 of 3
    await repo.activate(ids[1]); // bench becomes pending with 1 set
    clock.advance(const Duration(minutes: 40));
    await repo.finishSession(id);

    expect(await statuses(id), [done, skipped, skipped]);
    final session = (await repo.findById(id))!;
    expect(session.endedAt, testNow.add(const Duration(minutes: 40)));
    expect(await repo.getActive(), isNull);
  });

  test(
    'a custom end time (forgotten session) is not before the start',
    () async {
      final id = await startSession();
      await repo.finishSession(
        id,
        endedAt: testNow.subtract(const Duration(hours: 1)),
      );
      expect((await repo.findById(id))!.endedAt, testNow);
    },
  );

  test('lastSetTime and notes', () async {
    final id = await startSession();
    expect(await repo.lastSetTime(id), isNull);
    clock.advance(const Duration(minutes: 7));
    await repo.saveSet(await seId(id, 0), w60);
    expect(await repo.lastSetTime(id), testNow.add(const Duration(minutes: 7)));
    await repo.updateNotes(id, '  Gut geschlafen ');
    expect((await repo.findById(id))!.notes, 'Gut geschlafen');
  });

  test('previous session of the same plan', () async {
    final planId = await plans.create('Push');
    final plan = (await plans.findById(planId))!;
    final first = await startSession(plan: plan);
    await repo.saveSet(await seId(first, 0), w60);
    await repo.finishSession(first);
    clock.advance(const Duration(days: 1));
    final free = await startSession();
    await repo.finishSession(free);
    clock.advance(const Duration(days: 1));
    final second = await startSession(plan: plan);

    final previous = await repo.previousPlanSessionDetails(
      (await repo.findById(second))!,
    );
    expect(previous!.first.sets.single.weightKg, 60);
    expect(
      await repo.previousPlanSessionDetails((await repo.findById(free))!),
      isNull,
    );
  });

  test('adopt order and added exercises into the plan', () async {
    final planId = await plans.create('Push');
    await plans.addExercise(planId, bench, targetSets: 3, targetReps: 8);
    await plans.addExercise(planId, squat, targetSets: 3, targetReps: 5);
    final plan = (await plans.findById(planId))!;
    final id = await repo.start(
      plan: plan,
      exercises: [
        SessionExerciseDraft(exerciseId: bench, targetSets: 3, targetReps: 8),
        SessionExerciseDraft(exerciseId: squat, targetSets: 3, targetReps: 5),
      ],
    );
    await repo.addExerciseToSession(
      id,
      plank,
      const ExerciseTargets(sets: 2, durationSec: 45),
    );
    final ids = [for (final d in await details(id)) d.sessionExercise.id];
    await repo.reorderSession(id, [ids[1], ids[2], ids[0]]);
    await repo.finishSession(id);

    await plans.adoptSession(planId, await details(id));
    final entries = await plans.getEntries(planId);
    expect(entries.map((e) => e.exercise.name), [
      'Kniebeuge',
      'Plank',
      'Bankdrücken',
    ]);
    expect(entries[1].planExercise.targetDurationSec, 45);
    expect(entries[0].planExercise.targetReps, 5, reason: 'targets kept');
  });

  test('save a free session as a plan (targets capped at 10 sets)', () async {
    final id = await startSession(sets: 3);
    await repo.addTargetSet(await seId(id, 0));
    final first = await seId(id, 0);
    for (var i = 0; i < 8; i++) {
      await repo.addTargetSet(first);
    }
    await repo.finishSession(id);
    final planId = await plans.createFromSession('Neu', await details(id));
    final entries = await plans.getEntries(planId);
    expect(entries.map((e) => e.exercise.name), [
      'Bankdrücken',
      'Kniebeuge',
      'Plank',
    ]);
    expect(entries.first.planExercise.targetSets, 10);
    expect((await repo.findById(id))!.isFreeTraining, isTrue);
  });

  test('actions on a finished session are refused', () async {
    final id = await startSession();
    final first = await seId(id, 0);
    await repo.finishSession(id);
    for (final action in [
      () => repo.activate(first),
      () => repo.skip(first),
      () => repo.addTargetSet(first),
      () => repo.saveSet(first, w60),
    ]) {
      await expectLater(action(), throwsA(isA<SessionNotActiveException>()));
    }
  });

  test('saveSet reports records, but not in the first session', () async {
    final first = await startSession(sets: 3);
    final a = await seId(first, 0);
    final s1 = await repo.saveSet(a, w60);
    final s2 = await repo.saveSet(a, const SetValues(weightKg: 70, reps: 10));
    expect(s1.records, isEmpty);
    expect(s2.records, isEmpty, reason: 'first session of the exercise');
    await repo.finishSession(first);

    clock.advance(const Duration(days: 2));
    final second = await startSession(sets: 3);
    final b = await seId(second, 0);
    final s3 = await repo.saveSet(b, const SetValues(weightKg: 70, reps: 10));
    expect(s3.records, isEmpty, reason: 'equal is not a record');
    final s4 = await repo.saveSet(b, const SetValues(weightKg: 72.5, reps: 3));
    expect(s4.records, [RecordKind.weight]);
    final s5 = await repo.saveSet(b, const SetValues(weightKg: 72.5, reps: 4));
    expect(s5.records, isEmpty, reason: 'e1RM 82.2 < 93.3, weight equal');

    final flagged = await repo.watchSessionRecords(second).first;
    expect(flagged.keys, [s4.set.id]);

    // Undo removes the record set; the flags follow.
    await repo.undoSave(s5);
    await repo.undoSave(s4);
    expect(await repo.watchSessionRecords(second).first, isEmpty);
  });
}
