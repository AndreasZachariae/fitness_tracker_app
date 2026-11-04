import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/exercise_repository.dart';
import 'package:gymlog/data/repositories/plan_repository.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/rest_timer.dart';

import '../../helpers/test_db.dart';

const pending = SessionExerciseStatus.pending;
const active = SessionExerciseStatus.active;
const done = SessionExerciseStatus.done;
const skipped = SessionExerciseStatus.skipped;
const w = SetValues(weightKg: 50, reps: 10);

/// Supersets and rotations (M9) in plans and sessions.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late PlanRepository plans;
  late SessionRepository sessions;
  late Map<String, int> ex;
  late int planId;

  setUp(() async {
    db = newTestDatabase();
    clock = newTestClock();
    plans = PlanRepository(db, clock);
    sessions = SessionRepository(db, clock);
    final exercises = ExerciseRepository(db, clock);
    ex = {
      for (final name in ['A', 'B', 'C', 'D', 'E'])
        name: await exercises.create(
          ExerciseDraft(name: name, type: ExerciseType.weightReps),
        ),
    };
    planId = await plans.create('Plan');
    for (final name in ['A', 'B', 'C', 'D', 'E']) {
      await plans.addExercise(planId, ex[name]!, targetSets: 2);
    }
  });
  tearDown(() => db.close());

  Future<List<PlanEntry>> entries() => plans.getEntries(planId);

  Future<int> entryId(String name) async => (await entries())
      .firstWhere((e) => e.exercise.id == ex[name])
      .planExercise
      .id;

  /// Plan as text: `A [B C] D` with `(…)` for rotations.
  Future<String> layout() async {
    final groups = await plans.getGroups(planId);
    final out = StringBuffer();
    int? open;
    for (final e in await entries()) {
      final g = e.planExercise.groupId;
      if (g != open) {
        if (open != null) {
          out.write(groups[open]!.kind == PlanGroupKind.superset ? ']' : ')');
        }
        if (g != null) {
          out.write(groups[g]!.kind == PlanGroupKind.superset ? ' [' : ' (');
        } else {
          out.write(' ');
        }
        open = g;
      } else {
        out.write(' ');
      }
      out.write(e.exercise.name);
    }
    if (open != null) {
      out.write(groups[open]!.kind == PlanGroupKind.superset ? ']' : ')');
    }
    return out.toString().replaceAll('  ', ' ').trim();
  }

  group('plan groups', () {
    test('create: members move to the first one, order kept', () async {
      final gid = await plans.createGroup(planId, PlanGroupKind.superset, [
        await entryId('D'),
        await entryId('B'),
      ], restSec: 60);
      expect(await layout(), 'A [B D] C E');
      final g = (await plans.getGroups(planId))[gid]!;
      expect(
        (g.kind, g.restSec, g.rotationExerciseId),
        (PlanGroupKind.superset, 60, null),
      );
      final positions = [
        for (final e in await entries()) e.planExercise.position,
      ];
      expect(positions, [0, 1, 2, 3, 4]);
    });

    test('rotation starts with its first member', () async {
      final gid = await plans.createGroup(planId, PlanGroupKind.rotation, [
        await entryId('E'),
        await entryId('C'),
      ]);
      expect(await layout(), 'A B (C E) D');
      expect((await plans.getGroups(planId))[gid]!.rotationExerciseId, ex['C']);
    });

    test('invalid groups are refused', () async {
      await expectLater(
        plans.createGroup(planId, PlanGroupKind.superset, [await entryId('A')]),
        throwsA(isA<InvalidValueException>()),
      );
      await plans.createGroup(planId, PlanGroupKind.superset, [
        await entryId('A'),
        await entryId('B'),
      ]);
      await expectLater(
        plans.createGroup(planId, PlanGroupKind.rotation, [
          await entryId('B'),
          await entryId('C'),
        ]),
        throwsA(isA<InvalidValueException>()),
        reason: 'B is already in a group (no nesting)',
      );
      await expectLater(
        plans.createGroup(planId, PlanGroupKind.superset, [
          await entryId('C'),
          await entryId('D'),
        ], restSec: -1),
        throwsA(isA<InvalidValueException>()),
      );
    });

    test('reorder must keep groups together', () async {
      await plans.createGroup(planId, PlanGroupKind.superset, [
        await entryId('B'),
        await entryId('C'),
      ]);
      final ids = [for (final e in await entries()) e.planExercise.id];
      // A [B C] D E → [C B] A D E is fine (inner order changed too).
      await plans.reorderEntries(planId, [
        ids[2],
        ids[1],
        ids[0],
        ids[3],
        ids[4],
      ]);
      expect(await layout(), '[C B] A D E');
      final now = [for (final e in await entries()) e.planExercise.id];
      await expectLater(
        plans.reorderEntries(planId, [now[0], now[2], now[1], now[3], now[4]]),
        throwsA(isA<InvalidValueException>()),
        reason: 'A between C and B splits the superset',
      );
    });

    test('add to group, remove from group, dissolve when too small', () async {
      final gid = await plans.createGroup(planId, PlanGroupKind.superset, [
        await entryId('A'),
        await entryId('B'),
      ]);
      await plans.addToGroup(gid, await entryId('E'));
      expect(await layout(), '[A B E] C D');
      await plans.removeFromGroup(await entryId('A'));
      expect(await layout(), '[B E] A C D');
      await plans.removeFromGroup(await entryId('E'));
      expect(await layout(), 'B E A C D');
      expect(await plans.getGroups(planId), isEmpty);
    });

    test('new exercise directly into a group', () async {
      final f = await ExerciseRepository(
        db,
        clock,
      ).create(const ExerciseDraft(name: 'F', type: ExerciseType.weightReps));
      final gid = await plans.createGroup(planId, PlanGroupKind.rotation, [
        await entryId('B'),
        await entryId('C'),
      ]);
      await plans.addExerciseToGroup(
        gid,
        f,
        const ExerciseTargets(sets: 4, reps: 12),
      );
      expect(await layout(), 'A (B C F) D E');
      final added = (await entries()).firstWhere((e) => e.exercise.id == f);
      expect(
        (added.planExercise.targetSets, added.planExercise.targetReps),
        (4, 12),
      );
    });

    test('dissolve keeps the exercises in place', () async {
      final gid = await plans.createGroup(planId, PlanGroupKind.superset, [
        await entryId('B'),
        await entryId('D'),
      ]);
      await plans.dissolveGroup(gid);
      expect(await layout(), 'A B D C E');
      expect(await plans.getGroups(planId), isEmpty);
    });

    test(
      'remove an entry with undo; the last member removes the group',
      () async {
        final gid = await plans.createGroup(planId, PlanGroupKind.superset, [
          await entryId('A'),
          await entryId('B'),
        ]);
        final removed = await plans.removeEntry(await entryId('A'));
        expect(await layout(), '[B] C D E');
        await plans.restoreEntry(removed);
        expect(await layout(), '[A B] C D E');

        final a = await plans.removeEntry(await entryId('A'));
        await plans.removeEntry(await entryId('B'));
        expect(await plans.getGroups(planId), isEmpty);
        await plans.restoreEntry(a);
        expect(
          await layout(),
          'A C D E',
          reason: 'group gone → back as single',
        );
        expect(gid, isPositive);
      },
    );

    test('update: rest, rotation rhythm; set the due exercise', () async {
      final gid = await plans.createGroup(planId, PlanGroupKind.rotation, [
        await entryId('A'),
        await entryId('B'),
      ]);
      final g = (await plans.getGroups(planId))[gid]!;
      await plans.updateGroup(g.copyWith(rotationEvery: 2));
      await plans.setRotationCurrent(gid, ex['B']!);
      final updated = (await plans.getGroups(planId))[gid]!;
      expect((updated.rotationEvery, updated.rotationExerciseId), (2, ex['B']));
      await expectLater(
        plans.setRotationCurrent(gid, ex['E']!),
        throwsA(isA<InvalidValueException>()),
      );
      await expectLater(
        plans.updateGroup(g.copyWith(rotationEvery: 11)),
        throwsA(isA<InvalidValueException>()),
      );
    });

    test('duplicate copies groups; deleting the plan deletes them', () async {
      await plans.createGroup(planId, PlanGroupKind.superset, [
        await entryId('A'),
        await entryId('B'),
      ], restSec: 45);
      final copy = await plans.duplicate(planId, 'Kopie');
      final groups = await plans.getGroups(copy);
      expect(groups.values.single.restSec, 45);
      final members = (await plans.getEntries(copy))
          .where((e) => e.planExercise.groupId == groups.keys.single);
      expect(members.map((e) => e.exercise.name), ['A', 'B']);
      await plans.delete(copy);
      expect(await plans.getGroups(copy), isEmpty);
      expect(await plans.getGroups(planId), hasLength(1));
    });
  });

  group('session supersets', () {
    /// Session with A, B (superset key 1, rest 60) and C.
    Future<int> start({int sets = 2}) => sessions.start(
      exercises: [
        SessionExerciseDraft(
          exerciseId: ex['A']!,
          targetSets: sets,
          supersetKey: 1,
          supersetRestSec: 60,
        ),
        SessionExerciseDraft(
          exerciseId: ex['B']!,
          targetSets: sets,
          supersetKey: 1,
          supersetRestSec: 60,
        ),
        SessionExerciseDraft(exerciseId: ex['C']!, targetSets: sets),
      ],
    );

    Future<List<SessionExerciseDetail>> details(int id) =>
        sessions.getDetails(id);
    Future<int> se(int id, String name) async =>
        (await details(id))
            .firstWhere((d) => d.exercise.id == ex[name])
            .sessionExercise
            .id;
    Future<List<SessionExerciseStatus>> statuses(int id) async => [
      for (final d in await details(id)) d.sessionExercise.status,
    ];
    Future<int?> rest(int id) async => restAfterLatestSet(
      await details(id),
      await sessions.getSupersets(id),
      defaultRestSec: 90,
    )?.durationSec;

    test('start creates the superset; a lone key is no superset', () async {
      final id = await sessions.start(
        exercises: [
          SessionExerciseDraft(
            exerciseId: ex['A']!,
            targetSets: 2,
            supersetKey: 1,
            supersetRestSec: 30,
          ),
          SessionExerciseDraft(
            exerciseId: ex['B']!,
            targetSets: 2,
            supersetKey: 1,
          ),
          SessionExerciseDraft(
            exerciseId: ex['C']!,
            targetSets: 2,
            supersetKey: 2,
          ),
        ],
      );
      final supersets = await sessions.getSupersets(id);
      expect(supersets.values.single.restSec, 30);
      final d = await details(id);
      expect(d.map((x) => x.sessionExercise.supersetId), [
        supersets.keys.single,
        supersets.keys.single,
        null,
      ]);
    });

    test('A1 → B1 (no rest) → A2 (rest 60) → B2 → done, next marked', () async {
      final id = await start();
      final a = await se(id, 'A');
      final b = await se(id, 'B');

      await sessions.saveSet(a, w);
      expect(await statuses(id), [pending, active, pending]);
      expect(await rest(id), isNull, reason: 'mid-round: no rest');

      clock.advance(const Duration(minutes: 1));
      await sessions.saveSet(b, w);
      expect(await statuses(id), [active, pending, pending]);
      expect(await rest(id), 60);

      clock.advance(const Duration(minutes: 2));
      final a2 = await sessions.saveSet(a, w);
      expect(a2.completedExercise, isTrue);
      expect(await statuses(id), [done, active, pending]);
      expect(await rest(id), isNull);

      clock.advance(const Duration(minutes: 1));
      await sessions.saveSet(b, w);
      expect(await statuses(id), [
        done,
        done,
        pending,
      ], reason: 'no auto-activation after the superset by default');
      expect(await rest(id), 60);
    });

    test('undo restores the active member', () async {
      final id = await start();
      final saved = await sessions.saveSet(await se(id, 'A'), w);
      expect(await statuses(id), [pending, active, pending]);
      await sessions.undoSave(saved);
      expect(await statuses(id), [active, pending, pending]);
      expect((await details(id)).first.sets, isEmpty);
    });

    test('after the superset: autoActivateNext applies', () async {
      await SettingsRepository(db)
          .update((s) => s.copyWith(autoActivateNext: true));
      final id = await start(sets: 1);
      await sessions.saveSet(await se(id, 'A'), w);
      await sessions.saveSet(await se(id, 'B'), w);
      expect(await statuses(id), [done, done, active]);
    });

    test('skip and finish move on inside the superset', () async {
      final id = await start(sets: 3);
      await sessions.skip(await se(id, 'A'));
      expect(await statuses(id), [skipped, active, pending]);
      await sessions.saveSet(await se(id, 'B'), w);
      expect(await statuses(id), [
        skipped,
        active,
        pending,
      ], reason: 'B alone continues');
      expect(await rest(id), 60, reason: 'a lone member rests after each set');
      await sessions.finishExercise(await se(id, 'B'));
      expect(await statuses(id), [skipped, done, pending]);
    });

    test('create in a running session: open exercises only', () async {
      final id = await sessions.start(
        exercises: [
          for (final n in ['A', 'B', 'C', 'D'])
            SessionExerciseDraft(exerciseId: ex[n]!, targetSets: 1),
        ],
      );
      await sessions.saveSet(await se(id, 'A'), w); // A done
      await expectLater(
        sessions.createSuperset(id, [await se(id, 'A'), await se(id, 'B')]),
        throwsA(isA<InvalidValueException>()),
      );
      final sid = await sessions.createSuperset(id, [
        await se(id, 'D'),
        await se(id, 'B'),
      ], restSec: 45);
      expect((await details(id)).map((d) => d.exercise.name), [
        'A',
        'B',
        'D',
        'C',
      ]);
      expect((await sessions.getSupersets(id))[sid]!.restSec, 45);
      await sessions.updateSupersetRest(sid, 120);
      expect((await sessions.getSupersets(id))[sid]!.restSec, 120);

      // Add a new exercise right into the superset.
      await sessions.addExerciseToSession(
        id,
        ex['E']!,
        const ExerciseTargets(sets: 1),
        supersetId: sid,
      );
      expect((await details(id)).map((d) => d.exercise.name), [
        'A',
        'B',
        'D',
        'E',
        'C',
      ]);
      await sessions.removeFromSuperset(await se(id, 'B'));
      expect((await details(id)).map((d) => d.exercise.name), [
        'A',
        'D',
        'E',
        'B',
        'C',
      ]);
      await sessions.removeFromSuperset(await se(id, 'E'));
      expect(await sessions.getSupersets(id), isEmpty, reason: 'one left');
    });

    test('reorder: superset as a block, not split', () async {
      final id = await start();
      final ids = [for (final d in await details(id)) d.sessionExercise.id];
      await sessions.reorderSession(id, [ids[2], ids[1], ids[0]]);
      expect((await details(id)).map((d) => d.exercise.name), ['C', 'B', 'A']);
      await expectLater(
        sessions.reorderSession(id, [ids[1], ids[2], ids[0]]),
        throwsA(isA<InvalidValueException>()),
      );
    });

    test('dissolve keeps exercises and sets', () async {
      final id = await start();
      await sessions.saveSet(await se(id, 'A'), w);
      final sid = (await sessions.getSupersets(id)).keys.single;
      await sessions.dissolveSuperset(sid);
      final d = await details(id);
      expect(d.map((x) => x.sessionExercise.supersetId), [null, null, null]);
      expect(d.first.sets, hasLength(1));
    });

    test('deleting the session removes its supersets', () async {
      final id = await start();
      await sessions.delete(id);
      expect(await sessions.getSupersets(id), isEmpty);
    });
  });

  group('plan session with groups', () {
    late int rotationId;
    late Plan plan;

    setUp(() async {
      // A [B C] (D E)
      await plans.createGroup(planId, PlanGroupKind.superset, [
        await entryId('B'),
        await entryId('C'),
      ], restSec: 75);
      rotationId = await plans.createGroup(planId, PlanGroupKind.rotation, [
        await entryId('D'),
        await entryId('E'),
      ]);
      plan = (await plans.findById(planId))!;
    });

    /// Drafts as the training tab builds them.
    Future<int> startPlan() async {
      final groups = await plans.getGroups(planId);
      final drafts = <SessionExerciseDraft>[];
      final rotations = <int>{};
      final all = await entries();
      for (final e in all) {
        final p = e.planExercise;
        final g = groups[p.groupId];
        if (g?.kind == PlanGroupKind.rotation) {
          if (!rotations.add(g!.id)) continue;
          final members = all.where((x) => x.planExercise.groupId == g.id);
          final due = members.firstWhere(
            (x) => x.exercise.id == g.rotationExerciseId,
            orElse: () => members.first,
          );
          drafts.add(
            SessionExerciseDraft(exerciseId: due.exercise.id, targetSets: 1),
          );
          continue;
        }
        drafts.add(
          SessionExerciseDraft(
            exerciseId: p.exerciseId,
            targetSets: 1,
            supersetKey: g?.id,
            supersetRestSec: g?.restSec,
          ),
        );
      }
      return sessions.start(plan: plan, exercises: drafts);
    }

    Future<int?> due() async =>
        (await plans.getGroups(planId))[rotationId]!.rotationExerciseId;

    test('the rotation moves on only when its exercise was trained', () async {
      expect(await due(), ex['D']);

      var id = await startPlan();
      var d = await sessions.getDetails(id);
      expect(d.map((x) => x.exercise.name), ['A', 'B', 'C', 'D']);
      expect((await sessions.getSupersets(id)).values.single.restSec, 75);
      // D not trained (only A).
      await sessions.saveSet(d.first.sessionExercise.id, w);
      await sessions.finishSession(id);
      expect(await due(), ex['D']);

      id = await startPlan();
      d = await sessions.getDetails(id);
      await sessions.saveSet(d.last.sessionExercise.id, w); // D
      await sessions.finishSession(id);
      expect(await due(), ex['E']);

      id = await startPlan();
      d = await sessions.getDetails(id);
      expect(d.last.exercise.name, 'E');
      await sessions.saveSet(d.last.sessionExercise.id, w);
      await sessions.finishSession(id);
      expect(await due(), ex['D'], reason: 'wraps around');
    });

    test('every 2 trainings', () async {
      final g = (await plans.getGroups(planId))[rotationId]!;
      await plans.updateGroup(g.copyWith(rotationEvery: 2));
      final seen = <String>[];
      for (var i = 0; i < 4; i++) {
        final id = await startPlan();
        final last = (await sessions.getDetails(id)).last;
        seen.add(last.exercise.name);
        await sessions.saveSet(last.sessionExercise.id, w);
        await sessions.finishSession(id);
      }
      expect(seen, ['D', 'D', 'E', 'E']);
    });

    test('free trainings never move a rotation', () async {
      final id = await sessions.start(
        exercises: [SessionExerciseDraft(exerciseId: ex['D']!, targetSets: 1)],
      );
      await sessions.saveSet(
        (await sessions.getDetails(id)).single.sessionExercise.id,
        w,
      );
      await sessions.finishSession(id);
      expect(await due(), ex['D']);
    });

    test(
      'unchanged session does not change the plan; changes are adopted',
      () async {
        final id = await startPlan();
        await sessions.finishSession(id);
        var d = await sessions.getDetails(id);
        var supersets = await sessions.getSupersets(id);
        expect(await plans.sessionChangesPlan(planId, d, supersets), isFalse);

        // Second session: superset [A C], B single, rotation stays.
        final id2 = await startPlan();
        final ids = {
          for (final x in await sessions.getDetails(id2))
            x.exercise.name: x.sessionExercise.id,
        };
        final old = (await sessions.getSupersets(id2)).keys.single;
        await sessions.dissolveSuperset(old);
        await sessions.createSuperset(id2, [ids['A']!, ids['C']!], restSec: 30);
        await sessions.finishSession(id2);
        d = await sessions.getDetails(id2);
        supersets = await sessions.getSupersets(id2);
        expect(await plans.sessionChangesPlan(planId, d, supersets), isTrue);
        await plans.adoptSession(planId, d, supersets);
        expect(await layout(), '[A C] B (D E)');
        final groups = await plans.getGroups(planId);
        expect(
          groups.values
              .where((g) => g.kind == PlanGroupKind.superset)
              .single
              .restSec,
          30,
        );
        expect(groups, hasLength(2), reason: 'old superset deleted');
      },
    );

    test('"Als Plan speichern" keeps supersets', () async {
      final id = await startPlan();
      await sessions.finishSession(id);
      final newPlan = await plans.createFromSession(
        'Neu',
        await sessions.getDetails(id),
        await sessions.getSupersets(id),
      );
      final groups = await plans.getGroups(newPlan);
      expect(groups.values.single.kind, PlanGroupKind.superset);
      expect(groups.values.single.restSec, 75);
      expect(
        (await plans.getEntries(newPlan)).map((e) => e.planExercise.groupId),
        [null, groups.keys.single, groups.keys.single, null],
      );
    });
  });
}
