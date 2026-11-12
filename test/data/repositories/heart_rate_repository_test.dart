import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/heart_rate_repository.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// 1.5.0/1.5.1: buffer during the training, only summaries afterwards.
void main() {
  late AppDatabase db;
  late Repos r;
  late HeartRateRepository repo;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
    repo = HeartRateRepository(db);
  });
  tearDown(() => db.close());

  /// A training of [plan] at [start]: two sets of bench at +2 and +4 min,
  /// heart rate every second from +1 to +5 min.
  Future<int> train(int bench, Plan? plan, DateTime start) async {
    final clock = FixedClock(start);
    final sessions = SessionRepository(db, clock);
    final id = await sessions.start(
      plan: plan,
      exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 2)],
    );
    final se = (await sessions.getDetails(id)).single.sessionExercise;
    await repo.addSamples(id, [
      for (var s = 60; s <= 300; s++)
        (at: start.add(Duration(seconds: s)), bpm: s < 120 ? 100 : 140),
    ]);
    clock.time = start.add(const Duration(minutes: 2));
    await sessions.addSet(se.id, weightKg: 60, reps: 10);
    clock.time = start.add(const Duration(minutes: 4));
    await sessions.addSet(se.id, weightKg: 60, reps: 8);
    clock.time = start.add(const Duration(minutes: 6));
    await sessions.finishSession(id);
    return id;
  }

  test('buffer only while the training runs; summaries at the end', () async {
    final bench = await addExercise(r, 'Bankdrücken');
    final planId = await r.plans.create('Push');
    final plan = (await r.plans.findById(planId))!;
    final id = await train(bench, plan, testNow);

    // The series is gone, the summaries are kept.
    expect(await repo.getSamples(id), isEmpty);
    final summary = (await repo.watchSummary(id).first)!;
    expect((summary.maxBpm, summary.minBpm), (140, 100));
    expect(summary.seconds, 241);
    expect(summary.perMinute, [null, 100, 140, 140, 140, 140]);
    expect(summary.distribution, {100: 60, 140: 181});

    final details = await r.sessions.getDetails(id);
    final sets = details.single.sets;
    // Set 1: 60–120 s (100) plus 120–140 s (140) for the peak.
    expect((sets[0].hrAvg, sets[0].hrPeak), (101, 140));
    expect((sets[1].hrAvg, sets[1].hrPeak), (140, 140));
    final se = details.single.sessionExercise;
    expect((se.hrMax, se.hrAvg), (140, 128));

    // Values after the end are not stored any more.
    expect(await repo.addSamples(id, [(at: testNow, bpm: 120)]), isFalse);
    expect(await repo.getSamples(id), isEmpty);
    expect(
      () => repo.addSamples(id, [(at: testNow, bpm: 300)]),
      throwsA(isA<InvalidValueException>()),
    );
  });

  test('earlier trainings: same plan, else all', () async {
    final bench = await addExercise(r, 'Bankdrücken');
    final push = (await r.plans.findById(await r.plans.create('Push')))!;
    final pull = (await r.plans.findById(await r.plans.create('Pull')))!;
    const day = Duration(days: 1);
    final a = await train(bench, push, testNow.subtract(day * 3));
    final b = await train(bench, pull, testNow.subtract(day * 2));
    final c = await train(bench, push, testNow.subtract(day));
    final d = await train(bench, pull, testNow);

    Future<Set<int>> earlier(int id) async => {
      for (final h in await repo.earlierSummaries(id)) h.sessionId,
    };
    expect(await earlier(c), {a});
    expect(await earlier(d), {b});
    // The first of its plan: all earlier trainings.
    expect(await earlier(b), {a});
    expect(await earlier(a), isEmpty);
    expect((await repo.allSummaries()).length, 4);
  });

  test('a deleted training takes its heart rate along', () async {
    final bench = await addExercise(r, 'Bankdrücken');
    final id = await r.sessions.start(
      exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 1)],
    );
    await repo.addSamples(id, [(at: testNow, bpm: 120)]);
    expect(await repo.getSamples(id), hasLength(1));
    await r.sessions.delete(id);
    expect(await repo.getSamples(id), isEmpty);
  });

  test('1.6.0: recovery and time in the warm-up target', () async {
    await SettingsRepository(db).update((x) => x.copyWith(hrThreshold: 170));
    final bike = await r.exercises.create(
      const ExerciseDraft(
        name: 'Ergometer',
        type: ExerciseType.timed,
        hrTargetZone: 2,
        hrTargetMinutes: 1,
      ),
    );
    final bench = await addExercise(r, 'Bankdrücken');
    final clock = FixedClock(testNow);
    final sessions = SessionRepository(db, clock);
    final id = await sessions.start(
      exercises: [
        SessionExerciseDraft(exerciseId: bike, targetSets: 1),
        SessionExerciseDraft(exerciseId: bench, targetSets: 1),
      ],
    );
    final ses = await sessions.getDetails(id);
    DateTime t(int s) => testNow.add(Duration(seconds: s));
    await repo.addSamples(id, [
      // Warm-up 0–90 s: 20 s below, 60 s in zone 2 (114–133), 10 s above.
      for (var s = 0; s < 20; s++) (at: t(s), bpm: 100),
      for (var s = 20; s < 80; s++) (at: t(s), bpm: 120),
      for (var s = 80; s < 90; s++) (at: t(s), bpm: 140),
      // Bench set ends at 300 s, peak 165 at 310 s, 60 s later 125.
      for (var s = 240; s < 310; s++) (at: t(s), bpm: 150),
      (at: t(310), bpm: 165),
      for (var s = 311; s <= 380; s++) (at: t(s), bpm: 125),
    ]);
    clock.time = t(90);
    await sessions.addSet(ses[0].sessionExercise.id, durationSec: 90);
    clock.time = t(300);
    await sessions.addSet(ses[1].sessionExercise.id, weightKg: 80, reps: 5);
    clock.time = t(400);
    await sessions.finishSession(id);

    final details = await sessions.getDetails(id);
    expect(details[0].sets.single.hrTargetSec, 60);
    expect(details[1].sets.single.hrTargetSec, isNull);
    final summary = (await repo.watchSummary(id).first)!;
    // The warm-up peak (140) has no value a minute later: only the bench
    // set (peak 165, zone 4).
    expect(summary.recoveryBpm, 40);
  });

  test('1.6.0: values are checked', () async {
    expect(
      () => r.exercises.create(
        const ExerciseDraft(
          name: 'X',
          type: ExerciseType.timed,
          hrTargetZone: 6,
          hrTargetMinutes: 5,
        ),
      ),
      throwsA(isA<InvalidValueException>()),
    );
    expect(
      () => r.exercises.create(
        const ExerciseDraft(
          name: 'Y',
          type: ExerciseType.timed,
          hrTargetZone: 2,
          hrTargetBpm: 120,
          hrTargetMinutes: 5,
        ),
      ),
      throwsA(isA<InvalidValueException>()),
    );
    for (final bad in [
      (AppSettings x) => x.copyWith(hrThreshold: 79),
      (AppSettings x) => x.copyWith(hrThreshold: 231),
      (AppSettings x) => x.copyWith(birthYear: 1800),
      (AppSettings x) => x.copyWith(hrWarnBpm: 300),
      (AppSettings x) => x.copyWith(hrPauseBpm: 20),
    ]) {
      expect(
        () => SettingsRepository(db).update(bad),
        throwsA(isA<InvalidValueException>()),
      );
    }
    final s = await SettingsRepository(db).update(
      (x) => x.copyWith(hrThreshold: 170, birthYear: 1990, sex: Sex.male),
    );
    // Default pause: end of zone 1.
    expect((s.pauseBpm, s.hrWarnBpm), (113, null));
    expect(
      (await SettingsRepository(db).update((x) => x.copyWith(hrPauseBpm: 105)))
          .pauseBpm,
      105,
    );
  });
}
