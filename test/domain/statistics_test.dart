import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/names.dart';
import 'package:gymlog/domain/period.dart';
import 'package:gymlog/domain/records.dart';
import 'package:gymlog/domain/statistics.dart';

// --- tiny builders --------------------------------------------------------

int _ids = 0;

Exercise ex(
  int id,
  ExerciseType type, {
  bool index = true,
  ExerciseCategory? category,
  String? name,
}) => Exercise(
  id: id,
  name: name ?? 'E$id',
  type: type,
  category: category,
  incrementKg: 2.5,
  restSec: null,
  includeInStrengthIndex: index,
  notes: '',
  archived: false,
  createdAt: DateTime.utc(2026),
);

SetEntry s({double? w, int? r, int? d, bool warmup = false}) => SetEntry(
  id: ++_ids,
  sessionExerciseId: 0,
  setIndex: 1,
  weightKg: w,
  reps: r,
  durationSec: d,
  isWarmup: warmup,
  completedAt: DateTime.utc(2026),
);

/// A training on [day] (local noon) with {exercise: sets}.
Training tr(
  String day,
  Map<Exercise, List<SetEntry>> sets, {
  int minutes = 60,
}) {
  final d = LocalDate.parse(day);
  final start = DateTime(d.year, d.month, d.day, 12).toUtc();
  final id = ++_ids;
  return Training(
    session: Session(
      id: id,
      planId: null,
      planNameSnapshot: null,
      startedAt: start,
      endedAt: start.add(Duration(minutes: minutes)),
      notes: '',
    ),
    exercises: [
      for (final MapEntry(key: e, value: list) in sets.entries)
        SessionExerciseDetail(
          sessionExercise: SessionExercise(
            id: ++_ids,
            sessionId: id,
            exerciseId: e.id,
            position: 0,
            targetSets: 3,
            targetReps: null,
            targetDurationSec: null,
            restSec: null,
            status: SessionExerciseStatus.done,
            completedAt: null,
          ),
          exercise: e,
          sets: list,
        ),
    ],
  );
}

BodyWeightEntry bw(String day, double kg) => BodyWeightEntry(
  id: ++_ids,
  date: LocalDate.parse(day),
  weightKg: kg,
  createdAt: DateTime.utc(2026),
);

StatsData data(
  List<Training> t, {
  List<BodyWeightEntry> bodyWeights = const [],
}) => StatsData(trainings: t, bodyWeights: bodyWeights, exercises: const []);

final bench = ex(1, ExerciseType.weightReps, category: ExerciseCategory.chest);
final pull = ex(2, ExerciseType.bodyweight, category: ExerciseCategory.back);
final plank = ex(
  3,
  ExerciseType.timed,
  index: false,
  category: ExerciseCategory.core,
);

void main() {
  group('nearestBodyWeight (§7.3)', () {
    final list = [bw('2026-10-01', 80), bw('2026-10-11', 82)];
    final cases = <(String, double?)>[
      ('2026-09-01', 80), // before all
      ('2026-10-05', 80), // closer to 1.10.
      ('2026-10-06', 80), // tie (5/5) → earlier
      ('2026-10-07', 82),
      ('2026-12-01', 82), // after all
    ];
    for (final (day, expected) in cases) {
      test(day, () {
        expect(nearestBodyWeight(list, LocalDate.parse(day)), expected);
      });
    }
    test('none', () {
      expect(nearestBodyWeight(const [], LocalDate(2026, 1, 1)), isNull);
    });
  });

  group('performance P (§7.4)', () {
    test('weight_reps: max e1RM', () {
      expect(
        performance(ExerciseType.weightReps, [
          s(w: 60, r: 10),
          s(w: 70, r: 5),
          s(w: 100, r: 10, warmup: true),
        ], useBodyWeight: false),
        // 70 × 5 → 81.7 beats 60 × 10 → 80; the warm-up is ignored.
        closeTo(70 * (1 + 5 / 30), 1e-9),
      );
    });
    test('bodyweight with body weight data: e1RM of BW + added', () {
      expect(
        performance(
          ExerciseType.bodyweight,
          [s(w: 0, r: 10), s(w: 10, r: 5)],
          useBodyWeight: true,
          bodyWeight: 80,
        ),
        closeTo(80 * (1 + 10 / 30), 1e-9),
      );
    });
    test('bodyweight without body weight data: max reps', () {
      expect(
        performance(ExerciseType.bodyweight, [
          s(w: 0, r: 10),
          s(w: 10, r: 5),
        ], useBodyWeight: false),
        10,
      );
    });
    test('bodyweight with assistance below 0 load: undefined', () {
      expect(
        performance(
          ExerciseType.bodyweight,
          [s(w: -100, r: 10)],
          useBodyWeight: true,
          bodyWeight: 80,
        ),
        isNull,
      );
    });
    test('timed: max duration', () {
      expect(
        performance(ExerciseType.timed, [
          s(d: 45),
          s(d: 60),
        ], useBodyWeight: true),
        60,
      );
    });
  });

  group('metrics and series', () {
    test('metric chips per type, effective 1RM only with body weight', () {
      expect(
        metricsFor(ExerciseType.weightReps, hasBodyWeights: false).first,
        ExerciseMetric.estimatedOneRepMax,
      );
      expect(
        metricsFor(ExerciseType.bodyweight, hasBodyWeights: false),
        isNot(contains(ExerciseMetric.effectiveOneRepMax)),
      );
      expect(
        metricsFor(ExerciseType.bodyweight, hasBodyWeights: true).last,
        ExerciseMetric.effectiveOneRepMax,
      );
      expect(
        metricsFor(ExerciseType.timed, hasBodyWeights: true).first,
        ExerciseMetric.maxDuration,
      );
    });

    final sets = [s(w: 60, r: 10), s(w: 62.5, r: 8), s(w: 5, r: 7)];
    final values = <(ExerciseMetric, double?)>[
      (ExerciseMetric.maxWeight, 62.5),
      (ExerciseMetric.volume, 600 + 500 + 35),
      (ExerciseMetric.maxReps, 10),
      (ExerciseMetric.totalReps, 25),
      (ExerciseMetric.maxAddedWeight, 62.5),
    ];
    for (final (metric, expected) in values) {
      test('metricValue ${metric.name}', () {
        expect(metricValue(metric, sets), expected);
      });
    }
    test('effective 1RM needs body weight', () {
      expect(
        metricValue(ExerciseMetric.effectiveOneRepMax, [s(w: 0, r: 1)]),
        isNull,
      );
      expect(
        metricValue(ExerciseMetric.effectiveOneRepMax, [
          s(w: 0, r: 1),
        ], bodyWeight: 80),
        80,
      );
    });
    test('durations', () {
      final t = [s(d: 30), s(d: 45)];
      expect(metricValue(ExerciseMetric.maxDuration, t), 45);
      expect(metricValue(ExerciseMetric.totalDuration, t), 75);
    });

    test('series: one point per training, record points', () {
      final d = data([
        tr('2026-10-01', {
          bench: [s(w: 60, r: 10)],
        }),
        tr('2026-10-03', {
          plank: [s(d: 60)],
        }),
        tr('2026-10-05', {
          bench: [s(w: 60, r: 10)],
        }),
        tr('2026-10-08', {
          bench: [s(w: 65, r: 10)],
        }),
        tr('2026-10-10', {
          bench: [s(w: 20, r: 10, warmup: true)],
        }),
      ]);
      final series = exerciseSeries(d, bench.id, ExerciseMetric.maxWeight);
      expect(series.map((p) => p.value), [60, 60, 65]);
      expect(series.map((p) => p.isRecord), [false, false, true]);
      final summary = summarizeSeries(series);
      expect((summary.best, summary.change, summary.count), (65, 5, 3));
      expect(summary.changePercent, closeTo(5 / 60 * 100, 1e-9));
      expect(summarizeSeries(series.take(1).toList()).change, isNull);
    });

    test('exercises with data, most recent first', () {
      final d = data([
        tr('2026-10-01', {
          bench: [s(w: 60, r: 10)],
          plank: [s(d: 30)],
        }),
        tr('2026-10-05', {
          pull: [s(w: 0, r: 8)],
          plank: [],
        }),
      ]);
      expect(exercisesWithData(d).map((e) => e.id), [
        pull.id,
        bench.id,
        plank.id,
      ]);
    });
  });

  group('strength index (§7.5)', () {
    final today = LocalDate(2026, 11, 3);

    test('baseline = first training; mean over exercises in %', () {
      final d = data([
        tr('2026-10-05', {
          bench: [s(w: 60, r: 1)],
          pull: [s(w: 0, r: 10)],
        }),
        tr('2026-10-12', {
          bench: [s(w: 66, r: 1)],
          pull: [s(w: 0, r: 12)],
        }),
      ]);
      final idx = strengthIndex(d, LocalDate(2026, 10, 18));
      expect(idx.map((p) => p.monday), [
        LocalDate(2026, 10, 5),
        LocalDate(2026, 10, 12),
      ]);
      expect(idx.first.percent, closeTo(100, 1e-9));
      // bench 66/60 = 1.10, pull-ups 12/10 = 1.20 → 115 %
      expect(idx.last.percent, closeTo(115, 1e-9));
      expect(idx.last.exerciseCount, 2);
    });

    test('best P of the week counts', () {
      final d = data([
        tr('2026-10-05', {
          bench: [s(w: 100, r: 1)],
        }),
        tr('2026-10-13', {
          bench: [s(w: 90, r: 1)],
        }),
        tr('2026-10-15', {
          bench: [s(w: 110, r: 1)],
        }),
      ]);
      expect(
        strengthIndex(d, LocalDate(2026, 10, 18)).last.percent,
        closeTo(110, 1e-9),
      );
    });

    test('carried forward at most 8 weeks, then dropped until trained', () {
      final d = data([
        tr('2026-01-05', {
          bench: [s(w: 100, r: 1)],
          pull: [s(w: 0, r: 10)],
        }),
        tr('2026-01-12', {
          pull: [s(w: 0, r: 11)],
        }),
        // bench pauses from week 2026-01-12 on, pull-ups go on weekly
        for (var i = 2; i <= 12; i++)
          tr(LocalDate(2026, 1, 5).addDays(7 * i).toIsoString(), {
            pull: [s(w: 0, r: 10)],
          }),
      ]);
      final idx = strengthIndex(d, LocalDate(2026, 3, 30));
      final byMonday = {for (final p in idx) p.monday: p};
      // Week 8 after 5.1. (2.3.) still carries bench, week 9 (9.3.) not.
      expect(byMonday[LocalDate(2026, 3, 2)]!.exerciseCount, 2);
      expect(byMonday[LocalDate(2026, 3, 9)]!.exerciseCount, 1);
      expect(byMonday[LocalDate(2026, 3, 9)]!.percent, closeTo(100, 1e-9));
    });

    test(
      'exercises enter only from their first training; excluded ones never',
      () {
        final d = data([
          tr('2026-10-05', {
            bench: [s(w: 60, r: 1)],
            plank: [s(d: 60)],
          }),
          tr('2026-10-12', {
            pull: [s(w: 0, r: 10)],
            plank: [s(d: 90)],
          }),
        ]);
        final idx = strengthIndex(d, LocalDate(2026, 10, 12));
        expect(idx.first.exerciseCount, 1);
        expect(idx.last.exerciseCount, 2);
        expect(idx.last.percent, closeTo(100, 1e-9));
      },
    );

    test('bodyweight uses effective load as soon as body weight exists', () {
      final d = data(
        [
          tr('2026-10-05', {
            pull: [s(w: 0, r: 1)],
          }),
          tr('2026-10-12', {
            pull: [s(w: 8, r: 1)],
          }),
        ],
        bodyWeights: [bw('2026-10-01', 80)],
      );
      // (80 + 8) / 80 = 110 %
      expect(
        strengthIndex(d, LocalDate(2026, 10, 12)).last.percent,
        closeTo(110, 1e-9),
      );
    });

    test('weeks continue to today; empty data', () {
      final d = data([
        tr('2026-10-05', {
          bench: [s(w: 60, r: 1)],
        }),
      ]);
      expect(strengthIndex(d, today).last.monday, LocalDate(2026, 11, 2));
      expect(strengthIndex(data(const []), today), isEmpty);
    });
  });

  group('overall charts', () {
    final today = LocalDate(2026, 11, 3);
    final d = data([
      tr('2026-10-19', {
        bench: [s(w: 60, r: 10), s(w: 60, r: 10)],
      }, minutes: 50),
      tr('2026-10-21', {
        pull: [s(w: 0, r: 8)],
        plank: [s(d: 60)],
      }, minutes: 40),
      tr('2026-11-02', {
        bench: [s(w: 50, r: 10)],
      }, minutes: 70),
    ]);

    test('weekly volume (§7.6) with zero weeks', () {
      final v = weeklyVolume(d, today);
      expect(v.map((w) => w.monday), [
        LocalDate(2026, 10, 19),
        LocalDate(2026, 10, 26),
        LocalDate(2026, 11, 2),
      ]);
      expect(v.map((w) => w.value), [1200, 0, 500]);
    });

    test('heatmap: 26 weeks, sets per day, current week last', () {
      final h = trainingHeatmap(d, today);
      expect(h, hasLength(26));
      expect(h.last[0], 1, reason: 'Mo 2.11.');
      expect(h[23][0], 2, reason: 'Mo 19.10.');
      expect(h[23][2], 2, reason: 'Mi 21.10.: 1 + 1');
      expect(h.expand((w) => w).reduce((a, b) => a + b), 5);
    });

    test('average per week and streak', () {
      expect(trainingsPerWeek(d, StatsPeriod.all, today), closeTo(1, 1e-9));
      expect(currentStreak(d, today), 1, reason: 'week of 26.10. is empty');
      final continuous = data([
        tr('2026-10-19', {
          bench: [s(w: 60, r: 1)],
        }),
        tr('2026-10-28', {
          bench: [s(w: 60, r: 1)],
        }),
      ]);
      // Current week (2.11.) has no training yet: does not break the streak.
      expect(currentStreak(continuous, today), 2);
      expect(currentStreak(data(const []), today), 0);
    });

    test('longest streak, also when it is no longer active (1.0.1)', () {
      expect(longestStreak(d), 1, reason: '19.10. and 2.11., gap in between');
      expect(longestStreak(data(const [])), 0);
      final past = data([
        for (final day in [
          '2026-09-01', // week of 31.8.
          '2026-09-03', // same week, counts once
          '2026-09-08',
          '2026-09-15',
          '2026-10-06', // gap of two weeks
          '2026-10-13',
        ])
          tr(day, {
            bench: [s(w: 60, r: 1)],
          }),
      ]);
      expect(longestStreak(past), 3);
      expect(currentStreak(past, today), 0, reason: 'broken since 20.10.');
    });

    test('sets per category in the period', () {
      expect(setsPerCategory(d, StatsPeriod.all, today), {
        ExerciseCategory.chest: 3,
        ExerciseCategory.back: 1,
        ExerciseCategory.core: 1,
      });
      expect(
        setsPerCategory(d, StatsPeriod.fourWeeks, LocalDate(2026, 11, 20)),
        {ExerciseCategory.chest: 1},
      );
    });
  });

  test('records overview: best values with day, sorted by name', () {
    final a = ex(10, ExerciseType.weightReps, name: 'Zug');
    final b = ex(11, ExerciseType.timed, name: 'Ärmel');
    final d = data([
      tr('2026-10-01', {
        a: [s(w: 60, r: 10)],
        b: [s(d: 30)],
      }),
      tr('2026-10-05', {
        a: [s(w: 70, r: 2)],
      }),
    ]);
    final r = recordsOverview(d, compareNames);
    expect(r.map((e) => e.$1.name), ['Ärmel', 'Zug']);
    final zug = {for (final v in r.last.$2) v.kind: v};
    expect(zug[RecordKind.weight]!.value, 70);
    expect(zug[RecordKind.weight]!.day, LocalDate(2026, 10, 5));
    expect(zug[RecordKind.estimatedOneRepMax]!.value, closeTo(80, 1e-9));
    expect(zug[RecordKind.estimatedOneRepMax]!.day, LocalDate(2026, 10, 1));
  });
}
