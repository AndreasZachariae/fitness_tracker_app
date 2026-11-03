import 'package:drift/drift.dart';

import '../../../domain/models/models.dart';
import '../database.dart';
import '../tables.dart';

part 'exercises_dao.g.dart';

@DriftAccessor(tables: [Exercises, PlanExercises, SessionExercises])
class ExercisesDao extends DatabaseAccessor<AppDatabase>
    with _$ExercisesDaoMixin {
  ExercisesDao(super.attachedDatabase);

  Stream<List<Exercise>> watchByArchived({required bool archived}) =>
      (select(exercises)..where((e) => e.archived.equals(archived))).watch();

  Future<List<Exercise>> getAll() => select(exercises).get();

  Future<Exercise?> findById(int id) =>
      (select(exercises)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> insertExercise(ExercisesCompanion row) =>
      into(exercises).insert(row);

  Future<void> updateExercise(Exercise exercise) =>
      update(exercises).replace(exercise.toInsertable());

  Future<int> deleteById(int id) =>
      (delete(exercises)..where((e) => e.id.equals(id))).go();

  /// Whether the exercise occurs in any session.
  Future<bool> hasSessionHistory(int id) async {
    final row =
        await (selectOnly(sessionExercises)
              ..addColumns([sessionExercises.id])
              ..where(sessionExercises.exerciseId.equals(id))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<int> removeFromAllPlans(int id) =>
      (delete(planExercises)..where((p) => p.exerciseId.equals(id))).go();
}
