import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/demo/demo_data.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/set_validation.dart';

import '../../helpers/test_db.dart';

void main() {
  final data = generateDemoData(now: testNow);
  final today = LocalDate.fromDateTime(testNow);
  final firstMonday = today.addDays(1 - today.weekday).addDays(-7 * 15);

  Map<int, T> byId<T>(List<T> list, int Function(T) id) => {
    for (final x in list) id(x): x,
  };
  final exercises = byId(data.exercises, (e) => e.id);
  final sessionExercises = byId(data.sessionExercises, (e) => e.id);
  final sessions = byId(data.sessions, (s) => s.id);

  int weekOf(DateTime utc) =>
      LocalDate.fromDateTime(utc).differenceInDays(firstMonday) ~/ 7;

  test('is deterministic for the same seed and time', () {
    final again = generateDemoData(now: testNow);
    expect(again.sets.length, data.sets.length);
    expect(
      again.sessions.map((s) => s.startedAt),
      data.sessions.map((s) => s.startedAt),
    );
    expect(
      again.bodyWeights.map((b) => b.weightKg),
      data.bodyWeights.map((b) => b.weightKg),
    );
  });

  test('about 12 exercises of all types, two plans', () {
    expect(data.exercises.length, inInclusiveRange(12, 14));
    expect(
      data.exercises.map((e) => e.type).toSet(),
      ExerciseType.values.toSet(),
    );
    expect(data.exercises.where((e) => e.archived), hasLength(1));
    expect(data.plans.map((p) => p.name), ['Oberkörper', 'Unterkörper']);
    expect(data.planExercises, isNotEmpty);
  });

  test('16 weeks of training with free trainings and skipped weeks', () {
    final weeks = data.sessions.map((s) => weekOf(s.startedAt)).toSet();
    expect(weeks.reduce((a, b) => a < b ? a : b), 0);
    expect(weeks.length, inInclusiveRange(12, 14), reason: '2 skipped weeks');
    expect(data.sessions.where((s) => s.isFreeTraining), isNotEmpty);
    expect(data.sessions.where((s) => s.planId == 1), isNotEmpty);
    expect(data.sessions.where((s) => s.planId == 2), isNotEmpty);
    expect(data.sessions.length, inInclusiveRange(30, 60));
  });

  test('everything lies in the past and sessions are finished', () {
    for (final s in data.sessions) {
      expect(s.endedAt, isNotNull);
      expect(s.endedAt!.isAfter(s.startedAt), isTrue);
      expect(s.endedAt!.isBefore(testNow), isTrue);
      expect(s.planNameSnapshot == null, s.planId == null);
    }
    for (final b in data.bodyWeights) {
      expect(b.date.isAfter(today), isFalse);
    }
  });

  test('all times are UTC with millisecond precision', () {
    final times = [
      ...data.exercises.map((e) => e.createdAt),
      ...data.sessions.expand((s) => [s.startedAt, s.endedAt!]),
      ...data.sets.map((s) => s.completedAt),
      ...data.bodyWeights.map((b) => b.createdAt),
    ];
    for (final t in times) {
      expect(t.isUtc && t.microsecond == 0, isTrue, reason: '$t');
    }
  });

  test('every set is valid for its exercise type and lies in its session', () {
    for (final set in data.sets) {
      final se = sessionExercises[set.sessionExerciseId]!;
      final exercise = exercises[se.exerciseId]!;
      final session = sessions[se.sessionId]!;
      expect(
        validateSet(
          exercise.type,
          weightKg: set.weightKg,
          reps: set.reps,
          durationSec: set.durationSec,
        ),
        isNull,
        reason: '$set of ${exercise.name}',
      );
      expect(set.completedAt.isAfter(session.startedAt), isTrue);
      expect(set.completedAt.isBefore(session.endedAt!), isTrue);
    }
  });

  test('sets are numbered 1..n, status matches the sets', () {
    for (final se in data.sessionExercises) {
      final sets = data.sets
          .where((s) => s.sessionExerciseId == se.id)
          .toList();
      expect(sets.map((s) => s.setIndex), [
        for (var i = 1; i <= sets.length; i++) i,
      ]);
      if (se.status == SessionExerciseStatus.skipped) {
        expect(sets, isEmpty);
      } else {
        expect(se.status, SessionExerciseStatus.done);
        expect(sets.length, se.targetSets);
        expect(se.completedAt, sets.last.completedAt);
      }
    }
  });

  test('an exercise appears at most once per session', () {
    final pairs = data.sessionExercises.map((e) => (e.sessionId, e.exerciseId));
    expect(pairs.toSet().length, pairs.length);
  });

  test('weights progress with noise', () {
    final bench = data.exercises.firstWhere((e) => e.name == 'Bankdrücken');
    final benchSets = [
      for (final s in data.sets)
        if (sessionExercises[s.sessionExerciseId]!.exerciseId == bench.id) s,
    ];
    final early =
        benchSets.take(6).map((s) => s.weightKg!).reduce((a, b) => a + b) / 6;
    final late =
        benchSets
            .skip(benchSets.length - 6)
            .map((s) => s.weightKg!)
            .reduce((a, b) => a + b) /
        6;
    expect(late, greaterThan(early + 5));
    expect(benchSets.map((s) => s.weightKg).toSet().length, greaterThan(3));
    for (final s in benchSets) {
      expect(s.weightKg! % bench.incrementKg, 0, reason: 'plate-able weight');
    }
  });

  test('body weight 3–5 times per week with a slight downward trend', () {
    final perWeek = <int, int>{};
    for (final b in data.bodyWeights) {
      final w = b.date.differenceInDays(firstMonday) ~/ 7;
      perWeek[w] = (perWeek[w] ?? 0) + 1;
    }
    // The current week may be incomplete.
    for (final MapEntry(key: week, value: n) in perWeek.entries) {
      if (week < 15) expect(n, inInclusiveRange(3, 5), reason: 'week $week');
    }
    expect(
      data.bodyWeights.map((b) => b.date).toSet().length,
      data.bodyWeights.length,
    );
    final first =
        data.bodyWeights
            .take(5)
            .map((b) => b.weightKg)
            .reduce((a, b) => a + b) /
        5;
    final last =
        data.bodyWeights
            .skip(data.bodyWeights.length - 5)
            .map((b) => b.weightKg)
            .reduce((a, b) => a + b) /
        5;
    expect(first - last, inInclusiveRange(0.5, 2.5));
  });

  test('ids are unique per table', () {
    for (final ids in [
      data.exercises.map((e) => e.id),
      data.sessions.map((e) => e.id),
      data.sessionExercises.map((e) => e.id),
      data.sets.map((e) => e.id),
      data.bodyWeights.map((e) => e.id),
    ]) {
      expect(ids.toSet().length, ids.length);
    }
  });

  test('a longer period works too (performance data)', () {
    final year = generateDemoData(now: testNow, weeks: 52);
    expect(year.sessions.length, greaterThan(120));
  });
}
