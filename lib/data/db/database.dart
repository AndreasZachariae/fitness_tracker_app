import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/models/models.dart';
import 'converters.dart';
import 'daos/body_weight_dao.dart';
import 'daos/exercises_dao.dart';
import 'daos/plans_dao.dart';
import 'daos/sessions_dao.dart';
import 'daos/settings_dao.dart';
import 'tables.dart';

part 'database.g.dart';

/// The app database (SPEC §5).
@DriftDatabase(
  tables: [
    Exercises,
    Plans,
    PlanExercises,
    Sessions,
    SessionExercises,
    SetEntries,
    BodyWeightEntries,
    AppSettingsTable,
  ],
  daos: [ExercisesDao, PlansDao, SessionsDao, BodyWeightDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens the database file of the app (in the app documents directory,
  /// separate per package, so the DEV app has its own data).
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'gymlog'));

  /// Current schema version. Changes only via migration (CLAUDE.md, rule 4).
  static const currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(appSettingsTable).insert(AppSettings.defaults.toInsertable());
    },
    // No onUpgrade yet: drift throws for unknown upgrades instead of
    // touching the data. From version 2 on: stepByStep(...) with tests.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Durable writes: a committed set survives app kill and power loss.
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = FULL');
      await settingsDao.ensureRow();
    },
  );
}
