import 'package:drift/drift.dart';

import '../../../domain/exercise_library.dart';
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

  /// All exercises including archived ones.
  Stream<List<Exercise>> watchAll() => select(exercises).watch();

  /// Number of plans containing the exercise.
  Future<int> planCount(int id) async {
    final count = planExercises.id.count();
    final row =
        await (selectOnly(planExercises)
              ..addColumns([count])
              ..where(planExercises.exerciseId.equals(id)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<Exercise?> findById(int id) =>
      (select(exercises)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> insertExercise(ExercisesCompanion row) =>
      into(exercises).insert(row);

  /// Inserts the library exercises whose names are not taken yet
  /// (archived exercises count as taken) and returns how many. [createdAt]
  /// in UTC; the caller provides the transaction.
  Future<int> addMissingLibraryExercises(DateTime createdAt) async {
    final missing = missingLibraryExercises(
      (await getAll()).map((e) => e.name),
    );
    await batch(
      (b) => b.insertAll(exercises, [
        for (final d in missing)
          ExercisesCompanion.insert(
            name: d.name,
            type: d.type,
            category: Value(d.category),
            incrementKg: Value(d.incrementKg),
            restSec: Value(d.restSec),
            includeInStrengthIndex: d.includeInStrengthIndex,
            notes: Value(d.notes),
            createdAt: createdAt,
            stepMode: Value(d.stepMode),
            incrementLbs: Value(d.incrementLbs),
            levelKg: Value(d.levelKg),
          ),
      ]),
    );
    return missing.length;
  }

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
