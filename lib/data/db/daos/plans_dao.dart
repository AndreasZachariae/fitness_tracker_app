import 'package:drift/drift.dart';

import '../../../domain/models/models.dart';
import '../database.dart';
import '../tables.dart';

part 'plans_dao.g.dart';

@DriftAccessor(tables: [Plans, PlanExercises, PlanGroups, Exercises])
class PlansDao extends DatabaseAccessor<AppDatabase> with _$PlansDaoMixin {
  PlansDao(super.attachedDatabase);

  SimpleSelectStatement<$PlansTable, Plan> _orderedPlans() => select(plans)
    ..orderBy([
      (p) => OrderingTerm.asc(p.position),
      (p) => OrderingTerm.asc(p.id),
    ]);

  Stream<List<Plan>> watchPlans() => _orderedPlans().watch();

  Future<List<Plan>> getPlans() => _orderedPlans().get();

  Future<Plan?> findById(int id) =>
      (select(plans)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> insertPlan(PlansCompanion row) => into(plans).insert(row);

  Future<void> updatePlan(Plan plan) =>
      update(plans).replace(plan.toInsertable());

  Future<int> deleteById(int id) =>
      (delete(plans)..where((p) => p.id.equals(id))).go();

  Future<int> nextPlanPosition() async {
    final max = plans.position.max();
    final row = await (selectOnly(plans)..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  Future<void> setPlanPosition(int id, int position) =>
      (update(plans)..where((p) => p.id.equals(id))).write(
        PlansCompanion(position: Value(position)),
      );

  JoinedSelectStatement<HasResultSet, dynamic> _entriesQuery(int planId) =>
      select(planExercises).join([
          innerJoin(
            exercises,
            exercises.id.equalsExp(planExercises.exerciseId),
          ),
        ])
        ..where(planExercises.planId.equals(planId))
        ..orderBy([
          OrderingTerm.asc(planExercises.position),
          OrderingTerm.asc(planExercises.id),
        ]);

  List<PlanEntry> _toEntries(List<TypedResult> rows) => [
    for (final row in rows)
      PlanEntry(
        planExercise: row.readTable(planExercises),
        exercise: row.readTable(exercises),
      ),
  ];

  Stream<List<PlanEntry>> watchEntries(int planId) =>
      _entriesQuery(planId).watch().map(_toEntries);

  Future<List<PlanEntry>> getEntries(int planId) async =>
      _toEntries(await _entriesQuery(planId).get());

  Future<PlanExercise?> findEntry(int id) =>
      (select(planExercises)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> insertEntry(PlanExercisesCompanion row) =>
      into(planExercises).insert(row);

  /// Inserts an entry with its original id and position (undo).
  Future<int> insertEntryWithId(PlanExercise entry) =>
      into(planExercises).insert(entry.toInsertable());

  /// Number of exercises per plan id (plans without exercises are missing).
  Stream<Map<int, int>> watchEntryCounts() {
    final count = planExercises.id.count();
    final query = selectOnly(planExercises)
      ..addColumns([planExercises.planId, count])
      ..groupBy([planExercises.planId]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(planExercises.planId)!: row.read(count)!,
      },
    );
  }

  Future<void> updateEntry(PlanExercise entry) =>
      update(planExercises).replace(entry.toInsertable());

  Future<int> deleteEntry(int id) =>
      (delete(planExercises)..where((p) => p.id.equals(id))).go();

  Future<bool> containsExercise(int planId, int exerciseId) async {
    final row =
        await (select(planExercises)
              ..where(
                (p) =>
                    p.planId.equals(planId) & p.exerciseId.equals(exerciseId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<int> nextEntryPosition(int planId) async {
    final max = planExercises.position.max();
    final row =
        await (selectOnly(planExercises)
              ..addColumns([max])
              ..where(planExercises.planId.equals(planId)))
            .getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  Future<void> setEntryPosition(int id, int position) =>
      (update(planExercises)..where((p) => p.id.equals(id))).write(
        PlanExercisesCompanion(position: Value(position)),
      );

  // Groups (M9)

  SimpleSelectStatement<$PlanGroupsTable, PlanGroup> _groups(int planId) =>
      select(planGroups)..where((g) => g.planId.equals(planId));

  Stream<List<PlanGroup>> watchGroups(int planId) => _groups(planId).watch();

  Future<List<PlanGroup>> getGroups(int planId) => _groups(planId).get();

  Future<PlanGroup?> findGroup(int id) =>
      (select(planGroups)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<int> insertGroup(PlanGroupsCompanion row) =>
      into(planGroups).insert(row);

  Future<void> updateGroup(PlanGroup group) =>
      update(planGroups).replace(group.toInsertable());

  Future<int> deleteGroup(int id) =>
      (delete(planGroups)..where((g) => g.id.equals(id))).go();

  Future<void> setEntryGroup(int entryId, int? groupId) =>
      (update(planExercises)..where((p) => p.id.equals(entryId))).write(
        PlanExercisesCompanion(groupId: Value(groupId)),
      );
}
