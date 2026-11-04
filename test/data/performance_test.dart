// Prints measured times; the test log is the place to read them.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/demo/demo_data.dart';
import 'package:gymlog/data/repositories/maintenance_repository.dart';
import 'package:gymlog/data/repositories/plan_repository.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/data/repositories/stats_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/serialization/backup.dart';
import 'package:gymlog/domain/serialization/csv_export.dart';

import '../helpers/test_db.dart';

/// M10 performance check: one year of demo data in a database file (WAL,
/// synchronous FULL as in the app). Limits are generous; on the phone the
/// times are a few times higher, the budget per tap is ~100 ms.
void main() {
  late Directory dir;
  late AppDatabase db;
  late FixedClock clock;
  final results = <String, double>{};

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('gymlog-perf');
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase(File('${dir.path}/gymlog.sqlite')),
        closeStreamsSynchronously: true,
      ),
    );
    clock = newTestClock();
  });

  tearDownAll(() async {
    await db.close();
    dir.deleteSync(recursive: true);
    print('--- performance with 1 year of demo data ---');
    for (final MapEntry(:key, :value) in results.entries) {
      print('${key.padRight(40)} ${value.toStringAsFixed(1)} ms');
    }
  });

  /// Average of [runs] runs of [action] after one warm-up.
  Future<double> measure(
    String name,
    Future<void> Function() action, {
    int runs = 3,
    required double limitMs,
  }) async {
    await action();
    final watch = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      await action();
    }
    final ms = watch.elapsedMicroseconds / 1000 / runs;
    results[name] = ms;
    expect(ms, lessThan(limitMs), reason: name);
    return ms;
  }

  test('one year of data: import, lists, session, summary, backup', () async {
    final data = generateDemoData(now: testNow, weeks: 52);
    expect(data.sessions.length, greaterThan(120));
    final maintenance = MaintenanceRepository(db);
    final sessions = SessionRepository(db, clock);
    final plans = PlanRepository(db, clock);

    var watch = Stopwatch()..start();
    await maintenance.replaceAll(data);
    results['replace all data (import)'] = watch.elapsedMicroseconds / 1000;
    expect(watch.elapsedMilliseconds, lessThan(5000));

    await measure(
      'history list (Verlauf)',
      () => sessions.watchHistory().first,
      limitMs: 300,
    );
    await measure(
      'last performances ("Zuletzt")',
      () => sessions.watchLastPerformances().first,
      limitMs: 200,
    );
    await measure(
      'statistics: load data',
      () => StatsRepository(db).load(),
      limitMs: 300,
    );
    await measure('plan entries + groups', () async {
      await plans.getEntries(1);
      await plans.getGroups(1);
    }, limitMs: 50);

    // A whole training of "Oberkörper" with every set.
    final plan = (await plans.findById(1))!;
    final entries = await plans.getEntries(plan.id);
    final groups = await plans.getGroups(plan.id);
    watch = Stopwatch()..start();
    final id = await sessions.start(
      plan: plan,
      exercises: [
        for (final e in entries)
          if (groups[e.planExercise.groupId]?.kind != PlanGroupKind.rotation)
            SessionExerciseDraft(
              exerciseId: e.exercise.id,
              targetSets: e.planExercise.targetSets,
              targetReps: e.planExercise.targetReps,
              supersetKey: e.planExercise.groupId,
            ),
      ],
    );
    results['start training'] = watch.elapsedMicroseconds / 1000;

    final saveTimes = <double>[];
    for (final d in await sessions.getDetails(id)) {
      for (var i = 0; i < d.sessionExercise.targetSets; i++) {
        clock.advance(const Duration(minutes: 2));
        final w = Stopwatch()..start();
        await sessions.saveSet(
          d.sessionExercise.id,
          d.exercise.type == ExerciseType.weightReps
              ? const SetValues(weightKg: 200, reps: 5)
              : const SetValues(weightKg: 0, reps: 20),
        );
        saveTimes.add(w.elapsedMicroseconds / 1000);
      }
    }
    saveTimes.sort();
    results['save a set (incl. records), median'] =
        saveTimes[saveTimes.length ~/ 2];
    results['save a set (incl. records), max'] = saveTimes.last;
    expect(saveTimes.last, lessThan(150));

    await measure('session view: details + record labels', () async {
      await sessions.getDetails(id);
      await sessions.watchSessionRecords(id).first;
    }, limitMs: 150);

    watch = Stopwatch()..start();
    await sessions.finishSession(id);
    results['finish training (incl. rotation)'] =
        watch.elapsedMicroseconds / 1000;

    await measure('summary: details, records, previous', () async {
      final s = (await sessions.findById(id))!;
      await sessions.getDetails(id);
      await sessions.sessionRecords(id);
      await sessions.previousPlanSessionDetails(s);
      await plans.sessionChangesPlan(
        plan.id,
        await sessions.getDetails(id),
        await sessions.getSupersets(id),
      );
    }, limitMs: 300);

    await measure(
      'backup: load + encode + decode',
      () async {
        final dataset = await maintenance.loadDataset();
        decodeBackup(
          encodeBackup(
            BackupData(
              dataset: dataset,
              settings: AppSettings.defaults,
              schemaVersion: AppDatabase.currentSchemaVersion,
              appVersion: '1.0.0+11',
              exportedAt: testNow,
            ),
          ),
        );
      },
      runs: 2,
      limitMs: 1500,
    );
    await measure(
      'CSV export',
      () async => buildCsvExport(await maintenance.loadDataset()),
      runs: 2,
      limitMs: 1500,
    );
  });
}
