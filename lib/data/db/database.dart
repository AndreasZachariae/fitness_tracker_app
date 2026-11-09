import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/clock.dart';
import '../../domain/legacy_steps.dart';
import '../../domain/models/models.dart';
import 'converters.dart';
import 'daos/body_weight_dao.dart';
import 'daos/exercises_dao.dart';
import 'daos/plans_dao.dart';
import 'daos/sessions_dao.dart';
import 'daos/settings_dao.dart';
import 'database.steps.dart';
import 'storage_time.dart';
import 'tables.dart';

part 'database.g.dart';

/// The app database (SPEC §5).
@DriftDatabase(
  tables: [
    Exercises,
    Plans,
    PlanExercises,
    PlanGroups,
    PlanSchedules,
    Sessions,
    SessionExercises,
    SessionSupersets,
    SetEntries,
    BodyWeightEntries,
    AppSettingsTable,
  ],
  daos: [ExercisesDao, PlansDao, SessionsDao, BodyWeightDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  /// With [libraryClock] a newly created database starts with the exercise
  /// library (v1.0.0); without it (tests) the database starts empty.
  AppDatabase(super.executor, {this.libraryClock});

  /// Opens the database file of the app (in the app documents directory,
  /// separate per package, so the DEV app has its own data).
  factory AppDatabase.open({required Clock clock}) =>
      AppDatabase(driftDatabase(name: 'gymlog'), libraryClock: clock);

  /// Clock for the creation time of the library exercises.
  final Clock? libraryClock;

  /// Current schema version. Changes only via migration (CLAUDE.md, rule 4).
  static const currentSchemaVersion = 4;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(appSettingsTable).insert(AppSettings.defaults.toInsertable());
      // Only on the very first start; existing databases are never changed
      // (Settings → Übungen can add the library later).
      if (libraryClock case final clock?) {
        await exercisesDao.addMissingLibraryExercises(storageTime(clock.now()));
      }
    },
    // Only additive steps (CLAUDE.md, rule 4); each step has a data
    // integrity test in test/data/db/migrations/gymlog/.
    onUpgrade: stepByStep(
      // M9: supersets and rotations.
      from1To2: (m, schema) async {
        await m.createTable(schema.planGroups);
        await m.createIndex(schema.planGroupsPlan);
        await m.addColumn(schema.planExercises, schema.planExercises.groupId);
        await m.createTable(schema.sessionSupersets);
        await m.createIndex(schema.sessionSupersetsSession);
        await m.addColumn(
          schema.sessionExercises,
          schema.sessionExercises.supersetId,
        );
      },
      // 1.1.0: weight steps (lbs plates, levels) and the default step.
      from2To3: (m, schema) async {
        await m.addColumn(schema.exercises, schema.exercises.stepMode);
        await m.addColumn(schema.exercises, schema.exercises.incrementLbs);
        await m.addColumn(schema.exercises, schema.exercises.levelKg);
        await m.addColumn(schema.appSettings, schema.appSettings.defaultStep);
        await m.addColumn(
          schema.appSettings,
          schema.appSettings.defaultStepUnit,
        );
        // Built-in machine and cable exercises use the new default step;
        // logged sets keep their kg values (decided by the user).
        Future<void> setMode(List<String> names, String mode, [double? kg]) =>
            customStatement(
              'UPDATE exercises SET step_mode = ?, level_kg = ? '
              "WHERE type = 'weight_reps' AND name COLLATE NOCASE IN "
              '(${List.filled(names.length, '?').join(', ')})',
              [mode, kg, ...names],
            );
        await setMode(v3StandardStepExercises, 'standard');
        await setMode(v3LevelExercises, 'levels', v3LevelKg);
      },
      // 1.2.0: training days of plans, notifications, update check.
      from3To4: (m, schema) async {
        await m.addColumn(schema.plans, schema.plans.active);
        await m.createTable(schema.planSchedules);
        await m.createIndex(schema.planSchedulesDay);
        final settings = schema.appSettings;
        for (final column in [
          settings.notifyEvening,
          settings.eveningMinute,
          settings.notifyBefore,
          settings.beforeMinutes,
          settings.notifyRest,
          settings.notifyOpenSession,
          settings.notifyBackup,
          settings.notifyStreak,
          settings.checkUpdates,
          settings.bookingUrl,
          settings.lastUpdateCheckAt,
          settings.latestVersion,
          settings.notificationsAsked,
        ]) {
          await m.addColumn(settings, column);
        }
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Durable writes: a committed set survives app kill and power loss.
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = FULL');
      // Only on the current schema (migration tests stop at older ones).
      if (details.versionNow == schemaVersion) await settingsDao.ensureRow();
    },
  );
}
