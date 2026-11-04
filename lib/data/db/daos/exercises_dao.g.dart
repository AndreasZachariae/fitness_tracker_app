// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercises_dao.dart';

// ignore_for_file: type=lint
mixin _$ExercisesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExercisesTable get exercises => attachedDatabase.exercises;
  $PlansTable get plans => attachedDatabase.plans;
  $PlanGroupsTable get planGroups => attachedDatabase.planGroups;
  $PlanExercisesTable get planExercises => attachedDatabase.planExercises;
  $SessionsTable get sessions => attachedDatabase.sessions;
  $SessionSupersetsTable get sessionSupersets =>
      attachedDatabase.sessionSupersets;
  $SessionExercisesTable get sessionExercises =>
      attachedDatabase.sessionExercises;
  ExercisesDaoManager get managers => ExercisesDaoManager(this);
}

class ExercisesDaoManager {
  final _$ExercisesDaoMixin _db;
  ExercisesDaoManager(this._db);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db.attachedDatabase, _db.exercises);
  $$PlansTableTableManager get plans =>
      $$PlansTableTableManager(_db.attachedDatabase, _db.plans);
  $$PlanGroupsTableTableManager get planGroups =>
      $$PlanGroupsTableTableManager(_db.attachedDatabase, _db.planGroups);
  $$PlanExercisesTableTableManager get planExercises =>
      $$PlanExercisesTableTableManager(_db.attachedDatabase, _db.planExercises);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db.attachedDatabase, _db.sessions);
  $$SessionSupersetsTableTableManager get sessionSupersets =>
      $$SessionSupersetsTableTableManager(
        _db.attachedDatabase,
        _db.sessionSupersets,
      );
  $$SessionExercisesTableTableManager get sessionExercises =>
      $$SessionExercisesTableTableManager(
        _db.attachedDatabase,
        _db.sessionExercises,
      );
}
