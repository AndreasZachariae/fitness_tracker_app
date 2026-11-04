import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/groups.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/rest_timer.dart';
import 'package:gymlog/domain/session_rules.dart';

const _pending = SessionExerciseStatus.pending;
const _active = SessionExerciseStatus.active;
const _done = SessionExerciseStatus.done;
const _skipped = SessionExerciseStatus.skipped;

SupersetMember m(
  int id,
  int sets, {
  int target = 3,
  SessionExerciseStatus status = _pending,
}) => (id: id, status: status, sets: sets, targetSets: target);

final _t0 = DateTime.utc(2026, 11, 3, 17);

SessionExercise se(
  int id, {
  int exerciseId = 0,
  int? superset,
  SessionExerciseStatus status = _pending,
  int target = 3,
  int? restSec,
}) => SessionExercise(
  id: id,
  sessionId: 1,
  exerciseId: exerciseId == 0 ? id * 10 : exerciseId,
  position: id,
  targetSets: target,
  targetReps: null,
  targetDurationSec: null,
  restSec: restSec,
  status: status,
  completedAt: null,
  supersetId: superset,
);

Exercise ex(int id, {int? restSec}) => Exercise(
  id: id,
  name: 'E$id',
  type: ExerciseType.weightReps,
  category: null,
  incrementKg: 2.5,
  restSec: restSec,
  includeInStrengthIndex: true,
  notes: '',
  archived: false,
  createdAt: _t0,
);

/// [setMinutes]: minute offsets of the sets.
SessionExerciseDetail detail(SessionExercise e, List<int> setMinutes) =>
    SessionExerciseDetail(
      sessionExercise: e,
      exercise: ex(e.exerciseId),
      sets: [
        for (final (i, min) in setMinutes.indexed)
          SetEntry(
            id: e.id * 100 + i,
            sessionExerciseId: e.id,
            setIndex: i + 1,
            weightKg: 50,
            reps: 10,
            durationSec: null,
            isWarmup: false,
            completedAt: _t0.add(Duration(minutes: min)),
          ),
      ],
    );

void main() {
  group('blocks', () {
    test('consecutive items of a group form one block', () {
      final items = [(1, null), (2, 7), (3, 7), (4, null), (5, 8), (6, 8)];
      final blocks = blocksOf(items, (i) => i.$2);
      expect(blocks.map((b) => b.items.map((i) => i.$1).toList()), [
        [1],
        [2, 3],
        [4],
        [5, 6],
      ]);
      expect(blocks.map((b) => b.isGroup), [false, true, false, true]);
      expect(flatten(blocks).map((i) => i.$1), [1, 2, 3, 4, 5, 6]);
    });

    test('a split group stays split, singles never merge', () {
      final items = [(1, 7), (2, null), (3, 7), (4, null), (5, null)];
      expect(blocksOf(items, (i) => i.$2).map((b) => b.items.length), [
        1,
        1,
        1,
        1,
        1,
      ]);
    });

    test('reorder keeps fixed items in place', () {
      bool movable(String s) => s.startsWith('m');
      final items = ['m1', 'F', 'm2', 'm3'];
      expect(reorderKeepingFixed(items, 3, 0, movable), [
        'm3',
        'F',
        'm1',
        'm2',
      ]);
      expect(reorderKeepingFixed(items, 0, 3, movable), [
        'm2',
        'F',
        'm3',
        'm1',
      ]);
      expect(reorderKeepingFixed(items, 1, 0, movable), isNull);
    });

    test('session blocks: superset moves as a whole, fixed blocks stay', () {
      final list = [
        se(1, status: _done),
        se(2),
        se(3, superset: 1),
        se(4, superset: 1),
      ];
      final blocks = blocksOf(list, (e) => e.supersetId);
      expect(reorderSessionBlocks(blocks, 2, 1), [1, 3, 4, 2]);
      expect(reorderSessionBlocks(blocks, 0, 2), isNull);

      // A superset with a done member is fixed.
      final mixed = [
        se(1),
        se(2, superset: 1, status: _done),
        se(3, superset: 1),
      ];
      final b2 = blocksOf(mixed, (e) => e.supersetId);
      expect(reorderSessionBlocks(b2, 1, 0), isNull);
      expect(reorderSessionBlocks(b2, 0, 1), [1, 2, 3]);
    });
  });

  group('superset flow (alternating)', () {
    test('two members, 3 sets each: A1 B1 | A2 B2 | A3 B3 |', () {
      // After A1: B has not done set 1 → B, no rest.
      expect(afterSupersetSet([m(1, 1, status: _active), m(2, 0)], 1, 1), (
        nextId: 2,
        roundEnd: false,
      ));
      // After B1: round over → A, rest.
      expect(afterSupersetSet([m(1, 1), m(2, 1, status: _active)], 2, 1), (
        nextId: 1,
        roundEnd: true,
      ));
      // After A3 (A done now): B still has set 3.
      expect(afterSupersetSet([m(1, 3, status: _done), m(2, 2)], 1, 3), (
        nextId: 2,
        roundEnd: false,
      ));
      // After B3: all done.
      expect(
        afterSupersetSet(
          [m(1, 3, status: _done), m(2, 3, status: _done)],
          2,
          3,
        ),
        (nextId: null, roundEnd: true),
      );
    });

    test('three members', () {
      final after = afterSupersetSet([m(1, 1), m(2, 1), m(3, 0)], 2, 1);
      expect(after, (nextId: 3, roundEnd: false));
      expect(afterSupersetSet([m(1, 1), m(2, 1), m(3, 1)], 3, 1), (
        nextId: 1,
        roundEnd: true,
      ));
    });

    test('unequal set counts: A 3, B 2 → A3 alone with rest', () {
      // After B2: round 2 over.
      expect(
        afterSupersetSet([m(1, 2), m(2, 2, target: 2, status: _done)], 2, 2),
        (nextId: 1, roundEnd: true),
      );
      // After A3: B is done, A done → superset finished.
      expect(
        afterSupersetSet(
          [m(1, 3, status: _done), m(2, 2, target: 2, status: _done)],
          1,
          3,
        ),
        (nextId: null, roundEnd: true),
      );
      // A has 4 sets, B 2: after A3 no partner left → rest after each set.
      expect(
        afterSupersetSet(
          [m(1, 3, target: 4), m(2, 2, target: 2, status: _done)],
          1,
          3,
        ),
        (nextId: 1, roundEnd: true),
      );
    });

    test('skipped members are left out', () {
      expect(afterSupersetSet([m(1, 1), m(2, 0, status: _skipped)], 1, 1), (
        nextId: 1,
        roundEnd: true,
      ));
    });

    test('next member after skip/finish wraps around', () {
      final members = [m(1, 1), m(2, 1, status: _skipped), m(3, 1)];
      expect(nextSupersetMember(members, 3), 1);
      expect(nextSupersetMember(members, 1), 3);
      expect(nextSupersetMember([m(1, 3, status: _done), m(2, 1)], 2), isNull);
    });
  });

  group('rest after the latest set', () {
    test('mid-round: no rest; round end: rest of the superset', () {
      final a = se(1, superset: 5, status: _pending);
      final b = se(2, superset: 5, status: _active);
      final supersets = {
        5: const SessionSuperset(id: 5, sessionId: 1, restSec: 60),
      };
      // A1 done, B1 open → no rest.
      expect(
        restAfterLatestSet(
          [
            detail(a, [0]),
            detail(b, []),
          ],
          supersets,
          defaultRestSec: 90,
        ),
        isNull,
      );
      // B1 done → 60 s after B1.
      final rest = restAfterLatestSet(
        [
          detail(a, [0]),
          detail(b, [1]),
        ],
        supersets,
        defaultRestSec: 90,
      );
      expect(rest!.durationSec, 60);
      expect(rest.set.sessionExerciseId, 2);
    });

    test('superset without own rest uses the rest of the last exercise', () {
      final a = se(1, superset: 5);
      final b = se(2, superset: 5, restSec: 45);
      final rest = restAfterLatestSet(
        [
          detail(a, [0]),
          detail(b, [1]),
        ],
        {5: const SessionSuperset(id: 5, sessionId: 1, restSec: null)},
        defaultRestSec: 90,
      );
      expect(rest!.durationSec, 45);
    });

    test('single exercises as before', () {
      final rest = restAfterLatestSet(
        [
          detail(se(1, restSec: 120), [0, 3]),
          detail(se(2), [1]),
        ],
        const {},
        defaultRestSec: 90,
      );
      expect((rest!.set.setIndex, rest.durationSec), (2, 120));
      expect(
        restAfterLatestSet([detail(se(1), [])], const {}, defaultRestSec: 90),
        isNull,
      );
    });
  });

  group('rotation', () {
    test('every training, only when trained', () {
      expect(
        advanceRotation(
          memberExerciseIds: [10, 20],
          currentExerciseId: 10,
          done: 0,
          every: 1,
          trained: true,
        ),
        (exerciseId: 20, done: 0),
      );
      expect(
        advanceRotation(
          memberExerciseIds: [10, 20],
          currentExerciseId: 20,
          done: 0,
          every: 1,
          trained: true,
        ),
        (exerciseId: 10, done: 0),
        reason: 'wraps around',
      );
      expect(
        advanceRotation(
          memberExerciseIds: [10, 20],
          currentExerciseId: 10,
          done: 0,
          every: 1,
          trained: false,
        ),
        (exerciseId: 10, done: 0),
      );
    });

    test('2 trainings per exercise, 3 members', () {
      var state = (exerciseId: null as int?, done: 0);
      final seen = <int?>[];
      for (var i = 0; i < 7; i++) {
        seen.add(rotationIndex([1, 2, 3], state.exerciseId));
        state = advanceRotation(
          memberExerciseIds: [1, 2, 3],
          currentExerciseId: state.exerciseId,
          done: state.done,
          every: 2,
          trained: true,
        );
      }
      expect(seen, [0, 0, 1, 1, 2, 2, 0]);
    });

    test('a removed current exercise falls back to the first member', () {
      expect(rotationIndex([1, 2], 99), 0);
      expect(rotationIndex([1, 2], null), 0);
      expect(
        advanceRotation(
          memberExerciseIds: [1, 2],
          currentExerciseId: 99,
          done: 3,
          every: 1,
          trained: true,
        ),
        (exerciseId: 2, done: 0),
      );
    });
  });

  group('layout', () {
    PlanExercise pe(int exerciseId, int position, [int? groupId]) =>
        PlanExercise(
          id: exerciseId,
          planId: 1,
          exerciseId: exerciseId,
          position: position,
          targetSets: 3,
          targetReps: null,
          targetDurationSec: null,
          restSec: null,
          groupId: groupId,
        );
    PlanGroup group(int id, PlanGroupKind kind, {int? restSec}) => PlanGroup(
      id: id,
      planId: 1,
      kind: kind,
      restSec: restSec,
      rotationEvery: 1,
      rotationExerciseId: null,
      rotationDone: 0,
    );

    final groups = {
      7: group(7, PlanGroupKind.superset, restSec: 60),
      8: group(8, PlanGroupKind.rotation),
    };
    final plan = planLayout([
      pe(1, 0),
      pe(2, 1, 7),
      pe(3, 2, 7),
      pe(4, 3, 8),
      pe(5, 4, 8),
      pe(6, 5),
    ], groups);

    test('plan layout', () {
      expect(plan, [
        const SingleBlock(1),
        const SupersetBlock([2, 3], restSec: 60, groupId: 7),
        const RotationBlock(8, [4, 5]),
        const SingleBlock(6),
      ]);
      expect(layoutExerciseIds(plan), [1, 2, 3, 4, 5, 6]);
    });

    List<LayoutBlock> session(List<SessionExercise> list, [int? rest = 60]) =>
        sessionLayout(list, {
          1: SessionSuperset(id: 1, sessionId: 1, restSec: rest),
        });

    test('unchanged session (rotation shows only one member)', () {
      final s = session([
        se(1, exerciseId: 1),
        se(2, exerciseId: 2, superset: 1),
        se(3, exerciseId: 3, superset: 1),
        se(4, exerciseId: 5),
        se(5, exerciseId: 6),
      ]);
      expect(sameLayout(adoptedLayout(plan, s), plan), isTrue);
    });

    test('changed order, new exercise, superset rest changed', () {
      final s = session([
        se(1, exerciseId: 6),
        se(2, exerciseId: 4),
        se(3, exerciseId: 3, superset: 1),
        se(4, exerciseId: 2, superset: 1),
        se(5, exerciseId: 1),
        se(6, exerciseId: 9),
      ], 90);
      expect(adoptedLayout(plan, s), [
        const SingleBlock(6),
        const RotationBlock(8, [4, 5]),
        const SupersetBlock([3, 2], restSec: 90, groupId: 7),
        const SingleBlock(1),
        const SingleBlock(9),
      ]);
    });

    test('superset formed in the session; plan superset dissolved', () {
      final s = session([
        se(1, exerciseId: 1, superset: 1),
        se(2, exerciseId: 6, superset: 1),
        se(3, exerciseId: 2),
        se(4, exerciseId: 3),
        se(5, exerciseId: 4),
      ]);
      expect(adoptedLayout(plan, s), [
        const SupersetBlock([1, 6], restSec: 60),
        const SingleBlock(2),
        const SingleBlock(3),
        const RotationBlock(8, [4, 5]),
      ]);
    });

    test('a rotation member in a session superset stays in the rotation', () {
      final s = session([
        se(1, exerciseId: 1, superset: 1),
        se(2, exerciseId: 4, superset: 1),
        se(3, exerciseId: 2),
        se(4, exerciseId: 3),
        se(5, exerciseId: 6),
      ]);
      expect(adoptedLayout(plan, s), [
        const SingleBlock(1),
        const RotationBlock(8, [4, 5]),
        const SingleBlock(2),
        const SingleBlock(3),
        const SingleBlock(6),
      ]);
    });

    test('plan exercises missing in the session stay at the end', () {
      final s = session([se(1, exerciseId: 6), se(2, exerciseId: 2)]);
      expect(adoptedLayout(plan, s), [
        const SingleBlock(6),
        const SingleBlock(2),
        const SingleBlock(1),
        const SingleBlock(3),
        const RotationBlock(8, [4, 5]),
      ]);
    });

    test('only singles: changed iff order or exercises differ', () {
      List<LayoutBlock> singles(List<int> ids) => [
        for (final id in ids) SingleBlock(id),
      ];
      final cases = <(String, List<int>, List<int>, bool)>[
        ('same order', [1, 2, 3], [1, 2, 3], false),
        ('other order', [1, 2, 3], [2, 1, 3], true),
        ('added exercise', [1, 2], [1, 2, 4], true),
        ('missing in session → moves to the end', [1, 2, 3], [1, 3], true),
        ('missing last one', [1, 2, 3], [1, 2], false),
        ('empty', [], [], false),
      ];
      for (final (name, p, s, changed) in cases) {
        expect(
          !sameLayout(adoptedLayout(singles(p), singles(s)), singles(p)),
          changed,
          reason: name,
        );
      }
    });

    test('a one-member session superset counts as single', () {
      expect(sessionLayout([se(1, exerciseId: 1, superset: 1)], const {}), [
        const SingleBlock(1),
      ]);
    });
  });
}
