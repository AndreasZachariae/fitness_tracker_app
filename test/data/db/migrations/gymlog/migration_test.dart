// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/db/database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

/// Migrations must keep every user data row (CLAUDE.md, rule 4).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // Every possible upgrade path ends in the schema of the code.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('migration from v1 to v2 keeps all data (groups added empty)', () async {
    const t = '2026-11-02T17:00:00.000Z';
    final oldExercises = [
      const v1.ExercisesData(
        id: 1,
        name: 'Bankdrücken',
        type: 'weight_reps',
        category: 'chest',
        incrementKg: 2.5,
        restSec: 120,
        includeInStrengthIndex: 1,
        notes: 'Griff eng',
        archived: 0,
        createdAt: t,
      ),
      const v1.ExercisesData(
        id: 2,
        name: 'Plank',
        type: 'timed',
        incrementKg: 2.5,
        includeInStrengthIndex: 0,
        notes: '',
        archived: 1,
        createdAt: t,
      ),
    ];
    final expectedExercises = [
      const v2.ExercisesData(
        id: 1,
        name: 'Bankdrücken',
        type: 'weight_reps',
        category: 'chest',
        incrementKg: 2.5,
        restSec: 120,
        includeInStrengthIndex: 1,
        notes: 'Griff eng',
        archived: 0,
        createdAt: t,
      ),
      const v2.ExercisesData(
        id: 2,
        name: 'Plank',
        type: 'timed',
        incrementKg: 2.5,
        includeInStrengthIndex: 0,
        notes: '',
        archived: 1,
        createdAt: t,
      ),
    ];
    final oldPlans = [
      const v1.PlansData(id: 1, name: 'Push', position: 0, createdAt: t),
    ];
    final expectedPlans = [
      const v2.PlansData(id: 1, name: 'Push', position: 0, createdAt: t),
    ];
    final oldPlanExercises = [
      const v1.PlanExercisesData(
        id: 1,
        planId: 1,
        exerciseId: 1,
        position: 0,
        targetSets: 3,
        targetReps: 10,
        restSec: 90,
      ),
      const v1.PlanExercisesData(
        id: 2,
        planId: 1,
        exerciseId: 2,
        position: 1,
        targetSets: 2,
        targetDurationSec: 45,
      ),
    ];
    final expectedPlanExercises = [
      const v2.PlanExercisesData(
        id: 1,
        planId: 1,
        exerciseId: 1,
        position: 0,
        targetSets: 3,
        targetReps: 10,
        restSec: 90,
      ),
      const v2.PlanExercisesData(
        id: 2,
        planId: 1,
        exerciseId: 2,
        position: 1,
        targetSets: 2,
        targetDurationSec: 45,
      ),
    ];
    final oldSessions = [
      const v1.SessionsData(
        id: 1,
        planId: 1,
        planNameSnapshot: 'Push',
        startedAt: t,
        endedAt: '2026-11-02T18:00:00.000Z',
        notes: 'gut',
      ),
      const v1.SessionsData(id: 2, startedAt: t, notes: ''),
    ];
    final expectedSessions = [
      const v2.SessionsData(
        id: 1,
        planId: 1,
        planNameSnapshot: 'Push',
        startedAt: t,
        endedAt: '2026-11-02T18:00:00.000Z',
        notes: 'gut',
      ),
      const v2.SessionsData(id: 2, startedAt: t, notes: ''),
    ];
    final oldSessionExercises = [
      const v1.SessionExercisesData(
        id: 1,
        sessionId: 1,
        exerciseId: 1,
        position: 0,
        targetSets: 3,
        targetReps: 10,
        status: 'done',
        completedAt: '2026-11-02T17:20:00.000Z',
      ),
      const v1.SessionExercisesData(
        id: 2,
        sessionId: 2,
        exerciseId: 1,
        position: 0,
        targetSets: 3,
        status: 'active',
      ),
    ];
    final expectedSessionExercises = [
      const v2.SessionExercisesData(
        id: 1,
        sessionId: 1,
        exerciseId: 1,
        position: 0,
        targetSets: 3,
        targetReps: 10,
        status: 'done',
        completedAt: '2026-11-02T17:20:00.000Z',
      ),
      const v2.SessionExercisesData(
        id: 2,
        sessionId: 2,
        exerciseId: 1,
        position: 0,
        targetSets: 3,
        status: 'active',
      ),
    ];
    final oldSets = [
      const v1.SetEntriesData(
        id: 1,
        sessionExerciseId: 1,
        setIndex: 1,
        weightKg: 62.5,
        reps: 10,
        isWarmup: 0,
        completedAt: '2026-11-02T17:10:00.000Z',
      ),
      const v1.SetEntriesData(
        id: 2,
        sessionExerciseId: 2,
        setIndex: 1,
        weightKg: 65,
        reps: 8,
        isWarmup: 0,
        completedAt: '2026-11-03T17:10:00.000Z',
      ),
    ];
    final expectedSets = [
      const v2.SetEntriesData(
        id: 1,
        sessionExerciseId: 1,
        setIndex: 1,
        weightKg: 62.5,
        reps: 10,
        isWarmup: 0,
        completedAt: '2026-11-02T17:10:00.000Z',
      ),
      const v2.SetEntriesData(
        id: 2,
        sessionExerciseId: 2,
        setIndex: 1,
        weightKg: 65,
        reps: 8,
        isWarmup: 0,
        completedAt: '2026-11-03T17:10:00.000Z',
      ),
    ];
    final oldBodyWeights = [
      const v1.BodyWeightEntriesData(
        id: 1,
        date: '2026-11-02',
        weightKg: 81.4,
        createdAt: t,
      ),
    ];
    final expectedBodyWeights = [
      const v2.BodyWeightEntriesData(
        id: 1,
        date: '2026-11-02',
        weightKg: 81.4,
        createdAt: t,
      ),
    ];
    final oldSettings = [
      const v1.AppSettingsData(
        id: 1,
        defaultSets: 4,
        defaultRestSec: 120,
        restTimerEnabled: 1,
        vibrationEnabled: 0,
        keepScreenOn: 1,
        autoActivateNext: 1,
        themeMode: 'dark',
        lastSelectedPlanId: 1,
        lastBackupAt: '2026-11-01T08:00:00.000Z',
        backupReminderDays: 7,
      ),
    ];
    final expectedSettings = [
      const v2.AppSettingsData(
        id: 1,
        defaultSets: 4,
        defaultRestSec: 120,
        restTimerEnabled: 1,
        vibrationEnabled: 0,
        keepScreenOn: 1,
        autoActivateNext: 1,
        themeMode: 'dark',
        lastSelectedPlanId: 1,
        lastBackupAt: '2026-11-01T08:00:00.000Z',
        backupReminderDays: 7,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.exercises, oldExercises);
        batch.insertAll(oldDb.plans, oldPlans);
        batch.insertAll(oldDb.planExercises, oldPlanExercises);
        batch.insertAll(oldDb.sessions, oldSessions);
        batch.insertAll(oldDb.sessionExercises, oldSessionExercises);
        batch.insertAll(oldDb.setEntries, oldSets);
        batch.insertAll(oldDb.bodyWeightEntries, oldBodyWeights);
        batch.insertAll(oldDb.appSettings, oldSettings);
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.exercises).get(), expectedExercises);
        expect(await newDb.select(newDb.plans).get(), expectedPlans);
        expect(
          await newDb.select(newDb.planExercises).get(),
          expectedPlanExercises,
        );
        expect(await newDb.select(newDb.sessions).get(), expectedSessions);
        expect(
          await newDb.select(newDb.sessionExercises).get(),
          expectedSessionExercises,
        );
        expect(await newDb.select(newDb.setEntries).get(), expectedSets);
        expect(
          await newDb.select(newDb.bodyWeightEntries).get(),
          expectedBodyWeights,
        );
        expect(await newDb.select(newDb.appSettings).get(), expectedSettings);
        expect(await newDb.select(newDb.planGroups).get(), isEmpty);
        expect(await newDb.select(newDb.sessionSupersets).get(), isEmpty);
      },
    );
  });

  test('after the upgrade the app reads the old data and can group', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      'INSERT INTO exercises (id, name, type, include_in_strength_index, '
      "created_at) VALUES (1, 'Bank', 'weight_reps', 1, "
      "'2026-11-01T10:00:00.000Z'), (2, 'Rudern', 'weight_reps', 1, "
      "'2026-11-01T10:00:00.000Z');"
      "INSERT INTO plans (id, name, position, created_at) VALUES (1, 'A', 0, "
      "'2026-11-01T10:00:00.000Z');"
      'INSERT INTO plan_exercises (id, plan_id, exercise_id, position, '
      'target_sets) VALUES (1, 1, 1, 0, 3), (2, 1, 2, 1, 3);',
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    final entries = await db.plansDao.getEntries(1);
    expect(entries.map((e) => e.planExercise.groupId), [null, null]);
    // The new tables and columns are usable right away.
    await db.customStatement(
      "INSERT INTO plan_groups (id, plan_id, kind) VALUES (1, 1, 'superset')",
    );
    await db.customStatement(
      'UPDATE plan_exercises SET group_id = 1 WHERE plan_id = 1',
    );
    expect(
      (await db.plansDao.getEntries(1)).map((e) => e.planExercise.groupId),
      [1, 1],
    );
    // Deleting the group keeps the exercises (ON DELETE SET NULL).
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement('DELETE FROM plan_groups WHERE id = 1');
    expect(
      (await db.plansDao.getEntries(1)).map((e) => e.planExercise.groupId),
      [null, null],
    );
  });
}
