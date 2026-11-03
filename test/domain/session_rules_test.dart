import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/session_rules.dart';

const p = SessionExerciseStatus.pending;
const a = SessionExerciseStatus.active;
const d = SessionExerciseStatus.done;
const sk = SessionExerciseStatus.skipped;

List<SessionExercise> list(List<SessionExerciseStatus> statuses) => [
  for (final (i, st) in statuses.indexed)
    SessionExercise(
      id: i + 1,
      sessionId: 1,
      exerciseId: i + 1,
      position: i,
      targetSets: 3,
      targetReps: null,
      targetDurationSec: null,
      restSec: null,
      status: st,
      completedAt: null,
    ),
];

void main() {
  group('reorderSessionExercises', () {
    final cases = <(String, List<SessionExerciseStatus>, int, int, List<int>?)>[
      ('pending moves freely', [p, p, p], 0, 2, [2, 3, 1]),
      ('active moves up', [p, p, a], 2, 0, [3, 1, 2]),
      ('done does not move', [d, p, p], 0, 2, null),
      ('skipped does not move', [p, sk, p], 1, 0, null),
      // 1=done stays first; pending 3 moves before pending 2
      ('done keeps its place', [d, p, p], 2, 1, [1, 3, 2]),
      // dragging across a done exercise: done stays in slot 2
      ('jumping over done', [p, d, p], 0, 2, [3, 2, 1]),
      ('no-op', [p, p], 0, 0, [1, 2]),
    ];
    for (final (name, statuses, from, to, expected) in cases) {
      test(name, () {
        expect(reorderSessionExercises(list(statuses), from, to), expected);
      });
    }
  });

  group('nextPendingExercise', () {
    test('first open after the given one, wrapping around', () {
      final l = list([p, d, p, d, p]);
      expect(nextPendingExercise(l, afterId: 2), 3);
      expect(nextPendingExercise(l, afterId: 4), 5);
      expect(nextPendingExercise(list([p, d, d]), afterId: 3), 1);
      expect(nextPendingExercise(l), 1);
      expect(nextPendingExercise(list([d, sk])), isNull);
    });
  });

  group('forgotten session', () {
    final session = Session(
      id: 1,
      planId: null,
      planNameSnapshot: null,
      startedAt: DateTime.utc(2026, 11, 3, 17),
      endedAt: null,
      notes: '',
    );
    test('older than 12 h', () {
      expect(
        isForgottenSession(session, DateTime.utc(2026, 11, 4, 5)),
        isFalse,
      );
      expect(
        isForgottenSession(session, DateTime.utc(2026, 11, 4, 5, 0, 1)),
        isTrue,
      );
      expect(
        isForgottenSession(
          session.copyWith(endedAt: DateTime.utc(2026, 11, 3, 18)),
          DateTime.utc(2026, 11, 5),
        ),
        isFalse,
      );
    });
    test('end = last set + 5 min, without sets the start', () {
      expect(
        forgottenSessionEnd(session, DateTime.utc(2026, 11, 3, 18, 2)),
        DateTime.utc(2026, 11, 3, 18, 7),
      );
      expect(forgottenSessionEnd(session, null), session.startedAt);
    });
  });

  group('sessionChangesPlan', () {
    final cases = <(String, List<int>, List<int>, bool)>[
      ('same order', [1, 2, 3], [1, 2, 3], false),
      ('other order', [1, 2, 3], [2, 1, 3], true),
      ('added exercise', [1, 2], [1, 2, 4], true),
      ('plan edited meanwhile (missing in session)', [1, 2, 3], [1, 3], false),
      ('empty', [], [], false),
    ];
    for (final (name, plan, session, expected) in cases) {
      test(name, () {
        expect(
          sessionChangesPlan(
            planExerciseIds: plan,
            sessionExerciseIds: session,
          ),
          expected,
        );
      });
    }
  });
}
