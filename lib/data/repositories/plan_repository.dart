import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../domain/models/models.dart';
import '../../domain/names.dart';
import '../db/database.dart';
import '../db/storage_time.dart';
import 'repository_exceptions.dart';

/// Allowed range of target sets in a plan (SPEC §5).
const minTargetSets = 1;
const maxTargetSets = 10;

/// Training plans and their exercises.
class PlanRepository {
  PlanRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// All plans in chip order.
  Stream<List<Plan>> watchPlans() => _db.plansDao.watchPlans();

  Future<List<Plan>> getPlans() => _db.plansDao.getPlans();

  Future<Plan?> findById(int id) => _db.plansDao.findById(id);

  /// Exercises of a plan in order.
  Stream<List<PlanEntry>> watchEntries(int planId) =>
      _db.plansDao.watchEntries(planId);

  Future<List<PlanEntry>> getEntries(int planId) =>
      _db.plansDao.getEntries(planId);

  /// Creates an empty plan at the end and returns its id.
  Future<int> create(String name) => _db.transaction(() async {
    final cleaned = await _checkName(name);
    return _db.plansDao.insertPlan(
      PlansCompanion.insert(
        name: cleaned,
        position: await _db.plansDao.nextPlanPosition(),
        createdAt: storageTime(_clock.now()),
      ),
    );
  });

  Future<void> rename(int id, String name) => _db.transaction(() async {
    final plan = await _require(id);
    final cleaned = await _checkName(name, excludeId: id);
    await _db.plansDao.updatePlan(
      Plan(
        id: plan.id,
        name: cleaned,
        position: plan.position,
        createdAt: plan.createdAt,
      ),
    );
  });

  /// Copies a plan with all exercises and targets; returns the new id.
  Future<int> duplicate(int id, String newName) => _db.transaction(() async {
    await _require(id);
    final newId = await create(newName);
    for (final entry in await _db.plansDao.getEntries(id)) {
      final p = entry.planExercise;
      await _db.plansDao.insertEntry(
        PlanExercisesCompanion.insert(
          planId: newId,
          exerciseId: p.exerciseId,
          position: p.position,
          targetSets: p.targetSets,
          targetReps: Value(p.targetReps),
          targetDurationSec: Value(p.targetDurationSec),
          restSec: Value(p.restSec),
        ),
      );
    }
    return newId;
  });

  /// Deletes the plan and its exercise list. Past sessions keep their
  /// `planNameSnapshot` (SPEC §5).
  Future<void> delete(int id) => _db.transaction(() async {
    await _require(id);
    await _db.plansDao.deleteById(id);
  });

  /// Sets the chip order; [planIds] must contain every plan exactly once.
  Future<void> reorder(List<int> planIds) => _db.transaction(() async {
    final current = (await _db.plansDao.getPlans()).map((p) => p.id).toSet();
    if (!_isPermutation(planIds, current)) {
      throw InvalidValueException('planIds', planIds);
    }
    for (var i = 0; i < planIds.length; i++) {
      await _db.plansDao.setPlanPosition(planIds[i], i);
    }
  });

  /// Adds an exercise at the end of a plan; returns the new entry id.
  Future<int> addExercise(
    int planId,
    int exerciseId, {
    required int targetSets,
    int? targetReps,
    int? targetDurationSec,
    int? restSec,
  }) => _db.transaction(() async {
    await _require(planId);
    final exercise = await _db.exercisesDao.findById(exerciseId);
    if (exercise == null) throw NotFoundException('exercise', exerciseId);
    _checkTargets(targetSets, targetReps, targetDurationSec, restSec);
    if (await _db.plansDao.containsExercise(planId, exerciseId)) {
      throw DuplicateExerciseException(exerciseId);
    }
    return _db.plansDao.insertEntry(
      PlanExercisesCompanion.insert(
        planId: planId,
        exerciseId: exerciseId,
        position: await _db.plansDao.nextEntryPosition(planId),
        targetSets: targetSets,
        targetReps: Value(targetReps),
        targetDurationSec: Value(targetDurationSec),
        restSec: Value(restSec),
      ),
    );
  });

  /// Saves targets of a plan entry (plan, exercise and position unchanged).
  Future<void> updateEntry(PlanExercise entry) => _db.transaction(() async {
    final existing = await _db.plansDao.findEntry(entry.id);
    if (existing == null) throw NotFoundException('planExercise', entry.id);
    _checkTargets(
      entry.targetSets,
      entry.targetReps,
      entry.targetDurationSec,
      entry.restSec,
    );
    await _db.plansDao.updateEntry(
      existing.copyWith(
        targetSets: entry.targetSets,
        targetReps: entry.targetReps,
        targetDurationSec: entry.targetDurationSec,
        restSec: entry.restSec,
      ),
    );
  });

  /// Removes an exercise from a plan and returns the removed entry.
  Future<PlanExercise> removeEntry(int entryId) => _db.transaction(() async {
    final existing = await _db.plansDao.findEntry(entryId);
    if (existing == null) throw NotFoundException('planExercise', entryId);
    await _db.plansDao.deleteEntry(entryId);
    return existing;
  });

  /// Sets the order of a plan's exercises; [entryIds] must contain every
  /// entry of the plan exactly once.
  Future<void> reorderEntries(int planId, List<int> entryIds) =>
      _db.transaction(() async {
        final current = (await _db.plansDao.getEntries(planId))
            .map((e) => e.planExercise.id)
            .toSet();
        if (!_isPermutation(entryIds, current)) {
          throw InvalidValueException('entryIds', entryIds);
        }
        for (var i = 0; i < entryIds.length; i++) {
          await _db.plansDao.setEntryPosition(entryIds[i], i);
        }
      });

  Future<Plan> _require(int id) async {
    final plan = await _db.plansDao.findById(id);
    if (plan == null) throw NotFoundException('plan', id);
    return plan;
  }

  Future<String> _checkName(String input, {int? excludeId}) async {
    if (!isValidName(input)) throw InvalidNameException(input);
    final key = nameKey(input);
    final all = await _db.plansDao.getPlans();
    if (all.any((p) => p.id != excludeId && nameKey(p.name) == key)) {
      throw DuplicateNameException(cleanName(input));
    }
    return cleanName(input);
  }

  static void _checkTargets(
    int targetSets,
    int? targetReps,
    int? targetDurationSec,
    int? restSec,
  ) {
    if (targetSets < minTargetSets || targetSets > maxTargetSets) {
      throw InvalidValueException('targetSets', targetSets);
    }
    if (targetReps != null && targetReps < 1) {
      throw InvalidValueException('targetReps', targetReps);
    }
    if (targetDurationSec != null && targetDurationSec < 1) {
      throw InvalidValueException('targetDurationSec', targetDurationSec);
    }
    if (restSec != null && (restSec < 0 || restSec > 3600)) {
      throw InvalidValueException('restSec', restSec);
    }
  }

  static bool _isPermutation(List<int> ids, Set<int> expected) =>
      ids.length == expected.length && ids.toSet().containsAll(expected);
}
