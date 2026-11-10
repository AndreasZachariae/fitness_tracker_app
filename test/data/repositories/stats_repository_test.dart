import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/demo/demo_data.dart';
import 'package:gymlog/data/repositories/maintenance_repository.dart';
import 'package:gymlog/data/repositories/stats_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/names.dart';
import 'package:gymlog/domain/period.dart';
import 'package:gymlog/domain/statistics.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  test('loads all finished trainings with details and body weights', () async {
    final demo = generateDemoData(now: testNow);
    await MaintenanceRepository(db).replaceAll(demo);
    final data = await StatsRepository(db).load();
    expect(data.trainings, hasLength(demo.sessions.length));
    expect(
      data.trainings.expand((t) => t.exercises).expand((e) => e.sets).length,
      demo.sets.length,
    );
    expect(data.bodyWeights, hasLength(demo.bodyWeights.length));
    // Oldest first, as the calculations expect.
    for (var i = 1; i < data.trainings.length; i++) {
      expect(
        data.trainings[i].session.startedAt.isBefore(
          data.trainings[i - 1].session.startedAt,
        ),
        isFalse,
      );
    }
    expect(
      data.bodyWeights.first.date.isBefore(data.bodyWeights.last.date),
      isTrue,
    );
  });

  test('one year of demo data: all statistics well below 50 ms', () async {
    await MaintenanceRepository(db)
        .replaceAll(generateDemoData(now: testNow, weeks: 52));
    final data = await StatsRepository(db).load();
    final today = LocalDate.fromDateTime(testNow);
    expect(data.trainings.length, greaterThan(120));

    final watch = Stopwatch()..start();
    for (var i = 0; i < 5; i++) {
      strengthIndex(data, today);
      trainingVolumes(data);
      trainingHeatmap(data, today);
      trainingsPerWeek(data, StatsPeriod.all, today);
      currentStreak(data, today);
      setsPerCategory(data, StatsPeriod.all, today);
      recordsOverview(data, compareNames);
      for (final e in exercisesWithData(data)) {
        for (final m in metricsFor(e.type, hasBodyWeights: true)) {
          exerciseSeries(data, e.id, m);
        }
      }
    }
    final perRun = watch.elapsedMilliseconds / 5;
    // ignore: avoid_print
    print('statistics with 1 year of data: ${perRun.toStringAsFixed(1)} ms');
    expect(perRun, lessThan(50));
  });
}
