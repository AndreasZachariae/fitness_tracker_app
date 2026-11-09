// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plans_dao.dart';

// ignore_for_file: type=lint
mixin _$PlansDaoMixin on DatabaseAccessor<AppDatabase> {
  $PlansTable get plans => attachedDatabase.plans;
  $ExercisesTable get exercises => attachedDatabase.exercises;
  $PlanGroupsTable get planGroups => attachedDatabase.planGroups;
  $PlanExercisesTable get planExercises => attachedDatabase.planExercises;
  $PlanSchedulesTable get planSchedules => attachedDatabase.planSchedules;
  PlansDaoManager get managers => PlansDaoManager(this);
}

class PlansDaoManager {
  final _$PlansDaoMixin _db;
  PlansDaoManager(this._db);
  $$PlansTableTableManager get plans =>
      $$PlansTableTableManager(_db.attachedDatabase, _db.plans);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db.attachedDatabase, _db.exercises);
  $$PlanGroupsTableTableManager get planGroups =>
      $$PlanGroupsTableTableManager(_db.attachedDatabase, _db.planGroups);
  $$PlanExercisesTableTableManager get planExercises =>
      $$PlanExercisesTableTableManager(_db.attachedDatabase, _db.planExercises);
  $$PlanSchedulesTableTableManager get planSchedules =>
      $$PlanSchedulesTableTableManager(_db.attachedDatabase, _db.planSchedules);
}
