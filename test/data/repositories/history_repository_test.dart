import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/exercise_repository.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late SessionRepository repo;
  late int bench, plank;

  setUp(() async {
    db = newTestDatabase();
    clock = newTestClock();
    repo = SessionRepository(db, clock);
    final exercises = ExerciseRepository(db, clock);
    bench = await exercises.create(
      const ExerciseDraft(name: 'Bankdrücken', type: ExerciseType.weightReps),
    );
    plank = await exercises.create(
      const ExerciseDraft(name: 'Plank', type: ExerciseType.timed),
    );
  });
  tearDown(() => db.close());

  Future<int> session(List<(double, int)> bench_, {int plankSec = 0}) async {
    final id = await repo.start(
      exercises: [
        SessionExerciseDraft(exerciseId: bench, targetSets: 3),
        SessionExerciseDraft(exerciseId: plank, targetSets: 1),
      ],
    );
    final d = await repo.getDetails(id);
    for (final (kg, reps) in bench_) {
      clock.advance(const Duration(minutes: 2));
      await repo.addSet(d[0].sessionExercise.id, weightKg: kg, reps: reps);
    }
    if (plankSec > 0) {
      await repo.addSet(d[1].sessionExercise.id, durationSec: plankSec);
    }
    clock.advance(const Duration(minutes: 30));
    await repo.finishSession(id);
    clock.advance(const Duration(days: 2));
    return id;
  }

  test('history: newest first with sets, volume and record mark', () async {
    final a = await session([(60, 10), (60, 10)], plankSec: 60);
    final b = await session([(60, 10)]);
    final c = await session([(65, 8)]);
    final active = await repo.start(exercises: const []);
    expect(active, isPositive);

    final history = await repo.watchHistory().first;
    expect(history.map((h) => h.session.id), [c, b, a]);
    final byId = {for (final h in history) h.session.id: h};
    expect(byId[a]!.setCount, 3, reason: 'incl. the timed set');
    expect(byId[a]!.volume, 1200, reason: 'weight_reps only');
    expect(byId[a]!.hasRecords, isFalse, reason: 'first session');
    expect(byId[b]!.hasRecords, isFalse, reason: 'not strictly greater');
    expect(byId[c]!.hasRecords, isTrue);
    expect(byId[a]!.duration, const Duration(minutes: 34));
  });

  test('history updates when a set is changed', () async {
    final a = await session([(60, 10)]);
    final values = <double>[];
    final sub = repo.watchHistory().listen((h) => values.add(h.single.volume));
    await pumpEventQueue();
    final set = (await repo.getDetails(a)).first.sets.single;
    await repo.updateSet(set.id, const SetValues(weightKg: 70, reps: 10));
    await pumpEventQueue();
    await sub.cancel();
    expect(values.first, 600);
    expect(values.last, 700);
  });

  test('updateSessionTimes validates and stores UTC', () async {
    final a = await session([(60, 10)]);
    final start = DateTime.utc(2026, 11, 1, 17);
    await repo.updateSessionTimes(
      a,
      start: start,
      end: start.add(const Duration(hours: 1)),
    );
    final s = (await repo.findById(a))!;
    expect(
      (s.startedAt, s.endedAt),
      (start, start.add(const Duration(hours: 1))),
    );

    await expectLater(
      repo.updateSessionTimes(a, start: start, end: start),
      throwsA(isA<InvalidValueException>()),
    );
    await expectLater(
      repo.updateSessionTimes(
        a,
        start: start,
        end: clock.now().add(const Duration(minutes: 1)),
      ),
      throwsA(isA<InvalidValueException>()),
    );
    final active = await repo.start(exercises: const []);
    await expectLater(
      repo.updateSessionTimes(
        active,
        start: start,
        end: start.add(const Duration(hours: 1)),
      ),
      throwsA(isA<InvalidValueException>()),
    );
  });

  test('removing an exercise deletes its sets only', () async {
    final a = await session([(60, 10)], plankSec: 45);
    final d = await repo.getDetails(a);
    await repo.removeSessionExercise(d.first.sessionExercise.id);
    final left = await repo.getDetails(a);
    expect(left.single.exercise.id, plank);
    expect(left.single.sets.single.durationSec, 45);
    expect((await repo.watchHistory().first).single.volume, 0);
  });
}
