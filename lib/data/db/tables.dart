// drift's documented pattern for CHECK constraints references the column
// getter inside its own definition (`x => integer().check(x.…)()`); drift_dev
// reads it at build time, it is never called recursively at runtime.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import '../../domain/models/models.dart';
import 'converters.dart';

// Tables of SPEC §5, schema version 1; groups (supersets, rotations) added in
// schema version 2 (M9). New columns of existing tables stay at the end so a
// migrated database has the same layout as a new one.
//
// CHECK lists of enum codes are literals on purpose: schema dumps must stay
// frozen even when an enum gains a value later (that needs a migration).
// test/data/db/schema_test.dart verifies they match the enums.
//
// NEVER change these definitions without a migration: bump `schemaVersion`,
// run `dart run drift_dev make-migrations`, write the step and its test.

@UseRowClass(Exercise, generateInsertable: true)
@TableIndex.sql(
  'CREATE UNIQUE INDEX exercises_name_unique ON exercises (name COLLATE NOCASE)',
)
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name =>
      text().check(name.trim().length.isBiggerThanValue(0))();
  TextColumn get type => text()
      .check(type.isIn(const ['weight_reps', 'bodyweight', 'timed']))
      .map(const ExerciseTypeConverter())();
  TextColumn get category => text()
      .nullable()
      .check(
        category.isIn(const [
          'chest',
          'back',
          'legs',
          'shoulders',
          'arms',
          'core',
          'full_body',
          'other',
        ]),
      )
      .map(const ExerciseCategoryConverter())();
  RealColumn get incrementKg => real()
      .withDefault(const Constant(2.5))
      .check(incrementKg.isBiggerThanValue(0))();
  IntColumn get restSec =>
      integer().nullable().check(restSec.isBiggerOrEqualValue(0))();
  BoolColumn get includeInStrengthIndex => boolean()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  // Schema 3 (1.1.0): weight steps.
  TextColumn get stepMode => text()
      .withDefault(const Constant('kg'))
      .check(stepMode.isIn(const ['standard', 'kg', 'lbs', 'levels']))
      .map(const StepModeConverter())();
  RealColumn get incrementLbs => real()
      .withDefault(const Constant(15))
      .check(incrementLbs.isBiggerThanValue(0))();
  RealColumn get levelKg =>
      real().nullable().check(levelKg.isBiggerThanValue(0))();
  // Schema 5 (1.3.0): the set timer of timed exercises counts down.
  BoolColumn get timerCountdown =>
      boolean().withDefault(const Constant(false))();
}

@UseRowClass(Plan, generateInsertable: true)
@TableIndex.sql(
  'CREATE UNIQUE INDEX plans_name_unique ON plans (name COLLATE NOCASE)',
)
class Plans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name =>
      text().check(name.trim().length.isBiggerThanValue(0))();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime()();
  // Schema 4 (1.2.0): only active plans remind.
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Training days of a plan with their local time (schema 4, 1.2.0).
@UseRowClass(PlanScheduleEntry, generateInsertable: true)
@TableIndex.sql(
  'CREATE UNIQUE INDEX plan_schedules_day ON plan_schedules '
  '(plan_id, weekday)',
)
class PlanSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId =>
      integer().references(Plans, #id, onDelete: KeyAction.cascade)();
  IntColumn get weekday => integer().check(weekday.isBetweenValues(1, 7))();
  IntColumn get minuteOfDay =>
      integer().check(minuteOfDay.isBetweenValues(0, 24 * 60 - 1))();
}

@UseRowClass(PlanExercise, generateInsertable: true)
@TableIndex(name: 'plan_exercises_plan', columns: {#planId, #position})
@TableIndex(name: 'plan_exercises_exercise', columns: {#exerciseId})
class PlanExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId =>
      integer().references(Plans, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.restrict)();
  IntColumn get position => integer()();
  IntColumn get targetSets =>
      integer().check(targetSets.isBetweenValues(1, 10))();
  IntColumn get targetReps =>
      integer().nullable().check(targetReps.isBiggerOrEqualValue(1))();
  IntColumn get targetDurationSec =>
      integer().nullable().check(targetDurationSec.isBiggerOrEqualValue(1))();
  IntColumn get restSec =>
      integer().nullable().check(restSec.isBiggerOrEqualValue(0))();

  // Schema 2
  IntColumn get groupId => integer().nullable().references(
    PlanGroups,
    #id,
    onDelete: KeyAction.setNull,
  )();

  @override
  List<Set<Column>> get uniqueKeys => [
    {planId, exerciseId},
  ];
}

/// Supersets and rotations of a plan (schema 2).
@UseRowClass(PlanGroup, generateInsertable: true)
@TableIndex(name: 'plan_groups_plan', columns: {#planId})
class PlanGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId =>
      integer().references(Plans, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()
      .check(kind.isIn(const ['superset', 'rotation']))
      .map(const PlanGroupKindConverter())();
  IntColumn get restSec =>
      integer().nullable().check(restSec.isBiggerOrEqualValue(0))();
  IntColumn get rotationEvery => integer()
      .withDefault(const Constant(1))
      .check(rotationEvery.isBetweenValues(1, 10))();

  /// No foreign key: a stale id simply means "first member".
  IntColumn get rotationExerciseId => integer().nullable()();
  IntColumn get rotationDone => integer()
      .withDefault(const Constant(0))
      .check(rotationDone.isBiggerOrEqualValue(0))();
}

@UseRowClass(Session, generateInsertable: true)
@TableIndex(name: 'sessions_started_at', columns: {#startedAt})
// At most one active session, enforced by the database as a last line of
// defense (the repository checks first). All indexed rows have the value 1.
@TableIndex.sql(
  'CREATE UNIQUE INDEX sessions_single_active '
  'ON sessions ((ended_at IS NULL)) WHERE ended_at IS NULL',
)
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().nullable().references(
    Plans,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get planNameSnapshot => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

@UseRowClass(SessionExercise, generateInsertable: true)
@TableIndex(name: 'session_exercises_session', columns: {#sessionId, #position})
@TableIndex(name: 'session_exercises_exercise', columns: {#exerciseId})
class SessionExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.restrict)();
  IntColumn get position => integer()();
  IntColumn get targetSets =>
      integer().check(targetSets.isBiggerOrEqualValue(1))();
  IntColumn get targetReps =>
      integer().nullable().check(targetReps.isBiggerOrEqualValue(1))();
  IntColumn get targetDurationSec =>
      integer().nullable().check(targetDurationSec.isBiggerOrEqualValue(1))();
  IntColumn get restSec =>
      integer().nullable().check(restSec.isBiggerOrEqualValue(0))();
  TextColumn get status => text()
      .check(status.isIn(const ['pending', 'active', 'done', 'skipped']))
      .map(const SessionExerciseStatusConverter())();
  DateTimeColumn get completedAt => dateTime().nullable()();

  // Schema 2
  IntColumn get supersetId => integer().nullable().references(
    SessionSupersets,
    #id,
    onDelete: KeyAction.setNull,
  )();

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, exerciseId},
  ];
}

/// Supersets of a session (schema 2).
@UseRowClass(SessionSuperset, generateInsertable: true)
@TableIndex(name: 'session_supersets_session', columns: {#sessionId})
class SessionSupersets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get restSec =>
      integer().nullable().check(restSec.isBiggerOrEqualValue(0))();
}

@UseRowClass(SetEntry, generateInsertable: true)
@TableIndex(
  name: 'set_entries_session_exercise',
  columns: {#sessionExerciseId, #setIndex},
)
class SetEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionExerciseId => integer().references(
    SessionExercises,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get setIndex => integer().check(setIndex.isBiggerOrEqualValue(1))();
  RealColumn get weightKg => real().nullable()();
  IntColumn get reps =>
      integer().nullable().check(reps.isBiggerOrEqualValue(1))();
  IntColumn get durationSec =>
      integer().nullable().check(durationSec.isBiggerOrEqualValue(1))();
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime()();
}

@UseRowClass(BodyWeightEntry, generateInsertable: true)
class BodyWeightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()
      .unique()
      .check(date.length.equals(10))
      .map(const LocalDateConverter())();
  RealColumn get weightKg => real().check(weightKg.isBiggerThanValue(0))();
  DateTimeColumn get createdAt => dateTime()();
}

@UseRowClass(AppSettings, generateInsertable: true)
class AppSettingsTable extends Table {
  @override
  String get tableName => 'app_settings';

  IntColumn get id => integer().check(id.equals(AppSettings.singletonId))();
  IntColumn get defaultSets => integer()
      .withDefault(const Constant(3))
      .check(defaultSets.isBetweenValues(1, 10))();
  IntColumn get defaultRestSec => integer()
      .withDefault(const Constant(90))
      .check(defaultRestSec.isBiggerOrEqualValue(0))();
  BoolColumn get restTimerEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get vibrationEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get keepScreenOn => boolean().withDefault(const Constant(true))();
  BoolColumn get autoActivateNext =>
      boolean().withDefault(const Constant(false))();
  TextColumn get themeMode => text()
      .withDefault(const Constant('system'))
      .check(themeMode.isIn(const ['system', 'light', 'dark']))
      .map(const ThemePreferenceConverter())();
  IntColumn get lastSelectedPlanId => integer().nullable().references(
    Plans,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get lastBackupAt => dateTime().nullable()();
  IntColumn get backupReminderDays => integer()
      .withDefault(const Constant(14))
      .check(backupReminderDays.isBiggerOrEqualValue(0))();
  // Schema 3 (1.1.0): default weight step.
  RealColumn get defaultStep => real()
      .withDefault(const Constant(15))
      .check(defaultStep.isBiggerThanValue(0))();
  TextColumn get defaultStepUnit => text()
      .withDefault(const Constant('lbs'))
      .check(defaultStepUnit.isIn(const ['kg', 'lbs']))
      .map(const WeightUnitConverter())();
  // Schema 4 (1.2.0): notifications and the update check.
  BoolColumn get notifyEvening => boolean().withDefault(const Constant(true))();
  IntColumn get eveningMinute => integer()
      .withDefault(const Constant(20 * 60))
      .check(eveningMinute.isBetweenValues(0, 24 * 60 - 1))();
  BoolColumn get notifyBefore => boolean().withDefault(const Constant(true))();
  IntColumn get beforeMinutes => integer()
      .withDefault(const Constant(60))
      .check(beforeMinutes.isBetweenValues(5, 24 * 60))();
  BoolColumn get notifyRest => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyOpenSession =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get notifyBackup => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyStreak => boolean().withDefault(const Constant(true))();
  BoolColumn get checkUpdates => boolean().withDefault(const Constant(true))();
  TextColumn get bookingUrl =>
      text().withDefault(const Constant(AppSettings.defaultBookingUrl))();
  DateTimeColumn get lastUpdateCheckAt => dateTime().nullable()();
  TextColumn get latestVersion => text().nullable()();
  BoolColumn get notificationsAsked =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
