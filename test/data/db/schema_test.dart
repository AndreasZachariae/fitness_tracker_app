import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/test_db.dart';
import 'migrations/generated/schema.dart';

/// Schema rules enforced by SQLite itself, independent of the repositories.
void main() {
  late AppDatabase db;

  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  Future<void> exec(String sql, [List<Object?> args = const []]) =>
      db.customStatement(sql, args);

  Future<Object?> scalar(String sql) async =>
      (await db.customSelect(sql).getSingle()).data.values.first;

  Future<void> seed() async {
    await exec(
      'INSERT INTO exercises (id, name, type, include_in_strength_index, '
      "created_at) VALUES (1, 'Bankdrücken', 'weight_reps', 1, "
      "'2026-11-01T10:00:00.000Z')",
    );
    await exec(
      'INSERT INTO plans (id, name, position, created_at) '
      "VALUES (1, 'Oberkörper', 0, '2026-11-01T10:00:00.000Z')",
    );
    await exec(
      'INSERT INTO plan_exercises (id, plan_id, exercise_id, position, '
      'target_sets) VALUES (1, 1, 1, 0, 3)',
    );
    await exec(
      'INSERT INTO sessions (id, plan_id, plan_name_snapshot, started_at, '
      "ended_at) VALUES (1, 1, 'Oberkörper', '2026-11-02T17:00:00.000Z', "
      "'2026-11-02T18:00:00.000Z')",
    );
    await exec(
      'INSERT INTO session_exercises (id, session_id, exercise_id, position, '
      "target_sets, status) VALUES (1, 1, 1, 0, 3, 'done')",
    );
    await exec(
      'INSERT INTO set_entries (id, session_exercise_id, set_index, '
      'weight_kg, reps, completed_at) VALUES (1, 1, 1, 60, 10, '
      "'2026-11-02T17:10:00.000Z')",
    );
  }

  test('schema of the code equals the dumped schema v1', () async {
    // Fails when tables change without bumping schemaVersion + new dump.
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(1);
    final dumped = AppDatabase(connection);
    addTearDown(dumped.close);
    await verifier.migrateAndValidate(dumped, 1);
    expect(AppDatabase.currentSchemaVersion, 1);
  });

  test('fresh database validates and has the settings row', () async {
    await db.validateDatabaseSchema();
    expect(await db.settingsDao.get(), AppSettings.defaults);
    expect(await scalar('SELECT COUNT(*) FROM app_settings'), 1);
  });

  test('foreign keys are enforced', () async {
    expect(await scalar('PRAGMA foreign_keys'), 1);
    await expectLater(
      exec(
        'INSERT INTO plan_exercises (plan_id, exercise_id, position, '
        'target_sets) VALUES (99, 99, 0, 3)',
      ),
      throwsA(anything),
    );
  });

  test('only one settings row with id 1 can exist', () async {
    await expectLater(
      exec('INSERT INTO app_settings (id) VALUES (2)'),
      throwsA(anything),
    );
    await expectLater(
      exec('INSERT INTO app_settings (id) VALUES (1)'),
      throwsA(anything),
    );
  });

  test('at most one active session (partial unique index)', () async {
    await exec(
      "INSERT INTO sessions (started_at) VALUES ('2026-11-03T17:00:00.000Z')",
    );
    await expectLater(
      exec(
        "INSERT INTO sessions (started_at) VALUES ('2026-11-03T17:05:00.000Z')",
      ),
      throwsA(anything),
    );
    // Any number of finished sessions is fine.
    for (var i = 0; i < 3; i++) {
      await exec(
        'INSERT INTO sessions (started_at, ended_at) VALUES '
        "('2026-11-0${i + 1}T17:00:00.000Z', '2026-11-0${i + 1}T18:00:00.000Z')",
      );
    }
    expect(await scalar('SELECT COUNT(*) FROM sessions'), 4);
  });

  test('deleting a session cascades to its exercises and sets', () async {
    await seed();
    await exec('DELETE FROM sessions WHERE id = 1');
    expect(await scalar('SELECT COUNT(*) FROM session_exercises'), 0);
    expect(await scalar('SELECT COUNT(*) FROM set_entries'), 0);
    expect(await scalar('SELECT COUNT(*) FROM exercises'), 1);
  });

  test('exercises with history cannot be deleted (restrict)', () async {
    await seed();
    await exec('DELETE FROM plan_exercises');
    await expectLater(
      exec('DELETE FROM exercises WHERE id = 1'),
      throwsA(anything),
    );
    expect(await scalar('SELECT COUNT(*) FROM set_entries'), 1);
  });

  test('deleting a plan keeps sessions and clears references', () async {
    await seed();
    await db.settingsDao.write(
      AppSettings.defaults.copyWith(lastSelectedPlanId: 1),
    );
    await exec('DELETE FROM plans WHERE id = 1');
    expect(await scalar('SELECT COUNT(*) FROM plan_exercises'), 0);
    final session = await db.sessionsDao.findById(1);
    expect(session!.planId, isNull);
    expect(session.planNameSnapshot, 'Oberkörper');
    expect((await db.settingsDao.get()).lastSelectedPlanId, isNull);
  });

  test('names are unique ignoring ASCII case (umlauts: repository)', () async {
    await seed();
    Future<void> insertExercise(String name) => exec(
      'INSERT INTO exercises (name, type, include_in_strength_index, '
      "created_at) VALUES (?, 'weight_reps', 1, '2026-11-01T10:00:00.000Z')",
      [name],
    );
    await expectLater(insertExercise('BANKDRüCKEN'), throwsA(anything));
    await expectLater(
      exec(
        'INSERT INTO plans (name, position, created_at) '
        "VALUES ('OBERKöRPER', 1, '2026-11-01T10:00:00.000Z')",
      ),
      throwsA(anything),
    );
    // SQLite NOCASE folds ASCII only; ExerciseRepository catches this case.
    await insertExercise('BANKDRÜCKEN');
  });

  test('an exercise appears at most once per plan and per session', () async {
    await seed();
    await expectLater(
      exec(
        'INSERT INTO plan_exercises (plan_id, exercise_id, position, '
        'target_sets) VALUES (1, 1, 1, 3)',
      ),
      throwsA(anything),
    );
    await expectLater(
      exec(
        'INSERT INTO session_exercises (session_id, exercise_id, position, '
        "target_sets, status) VALUES (1, 1, 1, 3, 'pending')",
      ),
      throwsA(anything),
    );
  });

  group('CHECK constraints', () {
    final invalid = {
      'target_sets 0': 'UPDATE plan_exercises SET target_sets = 0',
      'target_sets 11': 'UPDATE plan_exercises SET target_sets = 11',
      'target_reps 0': 'UPDATE plan_exercises SET target_reps = 0',
      'reps 0': 'UPDATE set_entries SET reps = 0',
      'duration 0': 'UPDATE set_entries SET duration_sec = 0',
      'set_index 0': 'UPDATE set_entries SET set_index = 0',
      'blank name': "UPDATE exercises SET name = '   '",
      'increment 0': 'UPDATE exercises SET increment_kg = 0',
      'unknown type': "UPDATE exercises SET type = 'cardio'",
      'unknown category': "UPDATE exercises SET category = 'cardio'",
      'unknown status': "UPDATE session_exercises SET status = 'running'",
      'unknown theme': "UPDATE app_settings SET theme_mode = 'blue'",
      'default_sets 0': 'UPDATE app_settings SET default_sets = 0',
      'bool not 0/1': 'UPDATE exercises SET archived = 2',
    };
    for (final MapEntry(key: name, value: sql) in invalid.entries) {
      test('rejects $name', () async {
        await seed();
        await expectLater(exec(sql), throwsA(anything));
      });
    }

    test('enum CHECK lists match the enums (all codes accepted)', () async {
      await seed();
      for (final t in ExerciseType.values) {
        await exec('UPDATE exercises SET type = ?', [t.code]);
      }
      for (final c in ExerciseCategory.values) {
        await exec('UPDATE exercises SET category = ?', [c.code]);
      }
      for (final s in SessionExerciseStatus.values) {
        await exec('UPDATE session_exercises SET status = ?', [s.code]);
      }
      for (final m in ThemePreference.values) {
        await exec('UPDATE app_settings SET theme_mode = ?', [m.code]);
      }
    });
  });

  test('times are stored as UTC ISO text with millisecond precision', () async {
    await db.sessionsDao.insertSession(
      SessionsCompanion.insert(startedAt: DateTime.utc(2026, 11, 3, 17, 20)),
    );
    expect(
      await scalar('SELECT started_at FROM sessions'),
      '2026-11-03T17:20:00.000Z',
    );
    final session = await db.sessionsDao.getActive();
    expect(session!.startedAt.isUtc, isTrue);
  });

  test('body weight dates are stored as YYYY-MM-DD and unique', () async {
    await db.bodyWeightDao.insertEntry(
      BodyWeightEntriesCompanion.insert(
        date: LocalDate(2026, 11, 3),
        weightKg: 81.5,
        createdAt: testNow,
      ),
    );
    expect(await scalar('SELECT date FROM body_weight_entries'), '2026-11-03');
    await expectLater(
      exec(
        'INSERT INTO body_weight_entries (date, weight_kg, created_at) '
        "VALUES ('2026-11-03', 80, '2026-11-03T08:00:00.000Z')",
      ),
      throwsA(anything),
    );
  });
}
