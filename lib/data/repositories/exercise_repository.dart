import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../domain/exercise_library.dart';
import '../../domain/models/models.dart';
import '../../domain/names.dart';
import '../../domain/weight_steps.dart';
import '../db/database.dart';
import '../db/storage_time.dart';
import 'repository_exceptions.dart';

/// Result of [ExerciseRepository.deleteOrArchive].
enum ExerciseRemoval {
  /// The exercise had no training history and was deleted.
  deleted,

  /// The exercise occurs in sessions and was archived instead (SPEC §5).
  archived,
}

/// The exercise library.
class ExerciseRepository {
  ExerciseRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Non-archived exercises, sorted by name.
  Stream<List<Exercise>> watchActive() =>
      _db.exercisesDao.watchByArchived(archived: false).map(_sortedByName);

  /// Archived exercises, sorted by name.
  Stream<List<Exercise>> watchArchived() =>
      _db.exercisesDao.watchByArchived(archived: true).map(_sortedByName);

  /// All exercises including archived ones (for lookups by id).
  Stream<List<Exercise>> watchAll() =>
      _db.exercisesDao.watchAll().map(_sortedByName);

  /// Non-archived exercises of the most recent sessions, newest first.
  Stream<List<Exercise>> watchRecentlyUsed({int limit = 6}) {
    return _db.sessionsDao.watchRecentExerciseIds(limit: limit * 2).asyncMap((
      ids,
    ) async {
      final result = <Exercise>[];
      for (final id in ids) {
        final e = await _db.exercisesDao.findById(id);
        if (e != null && !e.archived) result.add(e);
        if (result.length == limit) break;
      }
      return result;
    });
  }

  Future<Exercise?> findById(int id) => _db.exercisesDao.findById(id);

  /// All exercises, archived ones included.
  Future<List<Exercise>> getAll() => _db.exercisesDao.getAll();

  /// Number of plans that contain the exercise.
  Future<int> planCount(int id) => _db.exercisesDao.planCount(id);

  /// Creates an exercise and returns its id.
  Future<int> create(ExerciseDraft draft) => _db.transaction(() async {
    final name = await _checkName(draft.name);
    _checkValues(
      incrementKg: draft.incrementKg,
      restSec: draft.restSec,
      incrementLbs: draft.incrementLbs,
      levelKg: draft.levelKg,
    );
    _checkTarget(draft.hrTargetRange, draft.hrTargetBpm, draft.hrTargetMinutes);
    return _db.exercisesDao.insertExercise(
      ExercisesCompanion.insert(
        name: name,
        type: draft.type,
        category: Value(draft.category),
        incrementKg: Value(draft.incrementKg),
        restSec: Value(draft.restSec),
        includeInStrengthIndex: draft.includeInStrengthIndex,
        notes: Value(draft.notes.trim()),
        createdAt: storageTime(_clock.now()),
        stepMode: Value(draft.stepMode),
        incrementLbs: Value(draft.incrementLbs),
        levelKg: Value(draft.levelKg),
        restByHeartRate: Value(draft.restByHeartRate),
        hrTargetRange: Value(draft.hrTargetRange),
        hrTargetBpm: Value(draft.hrTargetBpm),
        hrTargetMinutes: Value(draft.hrTargetMinutes),
      ),
    );
  });

  /// Number of library exercises that [addLibrary] would add.
  Future<int> missingLibraryCount() async => missingLibraryExercises(
    (await _db.exercisesDao.getAll()).map((e) => e.name),
  ).length;

  /// Adds the library exercises whose names are not taken yet; existing
  /// exercises stay unchanged. Returns how many were added.
  Future<int> addLibrary() => _db.transaction(
    () =>
        _db.exercisesDao.addMissingLibraryExercises(storageTime(_clock.now())),
  );

  /// Saves changed fields of an existing exercise.
  Future<void> update(Exercise exercise) => _db.transaction(() async {
    final existing = await _db.exercisesDao.findById(exercise.id);
    if (existing == null) throw NotFoundException('exercise', exercise.id);
    final name = await _checkName(exercise.name, excludeId: exercise.id);
    _checkValues(
      incrementKg: exercise.incrementKg,
      restSec: exercise.restSec,
      incrementLbs: exercise.incrementLbs,
      levelKg: exercise.levelKg,
    );
    _checkTarget(
      exercise.hrTargetRange,
      exercise.hrTargetBpm,
      exercise.hrTargetMinutes,
    );
    final hasHistory = await _db.exercisesDao.hasSessionHistory(exercise.id);
    if (exercise.type != existing.type && hasHistory) {
      throw TypeChangeNotAllowedException(exercise.id);
    }
    if (hasHistory) await _convertStoredWeights(existing, exercise);
    await _db.exercisesDao.updateExercise(
      exercise.copyWith(name: name, notes: exercise.notes.trim()),
    );
  });

  /// Whether the set timer of this timed exercise counts down (1.3.0).
  Future<void> setTimerCountdown(int id, bool countdown) =>
      _db.transaction(() async {
        final existing = await _db.exercisesDao.findById(id);
        if (existing == null) throw NotFoundException('exercise', id);
        await _db.exercisesDao.updateExercise(
          existing.copyWith(timerCountdown: countdown),
        );
      });

  /// Removes the exercise from all plans; deletes it if it was never
  /// trained, otherwise archives it so the history stays intact.
  Future<ExerciseRemoval> deleteOrArchive(int id) => _db.transaction(() async {
    final existing = await _db.exercisesDao.findById(id);
    if (existing == null) throw NotFoundException('exercise', id);
    await _db.exercisesDao.removeFromAllPlans(id);
    if (await _db.exercisesDao.hasSessionHistory(id)) {
      await _db.exercisesDao.updateExercise(existing.copyWith(archived: true));
      return ExerciseRemoval.archived;
    }
    await _db.exercisesDao.deleteById(id);
    return ExerciseRemoval.deleted;
  });

  /// Brings an archived exercise back into the library.
  Future<void> restore(int id) => _db.transaction(() async {
    final existing = await _db.exercisesDao.findById(id);
    if (existing == null) throw NotFoundException('exercise', id);
    await _db.exercisesDao.updateExercise(existing.copyWith(archived: false));
  });

  /// Sets of levels without kg store the level number, all others kg
  /// (1.1.0). Switching between the two converts the logged sets with the
  /// kg per level; without one the switch is refused. Switching between kg
  /// based modes leaves the sets unchanged.
  Future<void> _convertStoredWeights(Exercise from, Exercise to) async {
    final fromKg = storesKg(from);
    final toKg = storesKg(to);
    if (fromKg == toKg) return;
    final factor = switch ((from.levelKg, to.levelKg)) {
      // Level numbers → kg of the new kg per level.
      (_, final kg?) when !fromKg && to.stepMode == StepMode.levels => kg,
      // Kg → level numbers with the old kg per level.
      (final kg?, _) when from.stepMode == StepMode.levels => 1 / kg,
      _ => throw StepChangeNotAllowedException(from.id),
    };
    await _db.customStatement(
      'UPDATE set_entries SET weight_kg = ROUND(weight_kg * ?, 2) '
      'WHERE weight_kg IS NOT NULL AND session_exercise_id IN '
      '(SELECT id FROM session_exercises WHERE exercise_id = ?)',
      [factor, from.id],
    );
  }

  /// Whether the exercise occurs in any session.
  Future<bool> hasHistory(int id) => _db.exercisesDao.hasSessionHistory(id);

  Future<String> _checkName(String input, {int? excludeId}) async {
    if (!isValidName(input)) throw InvalidNameException(input);
    final key = nameKey(input);
    final all = await _db.exercisesDao.getAll();
    if (all.any((e) => e.id != excludeId && nameKey(e.name) == key)) {
      throw DuplicateNameException(cleanName(input));
    }
    return cleanName(input);
  }

  static void _checkValues({
    required double incrementKg,
    int? restSec,
    double incrementLbs = Exercise.defaultIncrementLbs,
    double? levelKg,
  }) {
    if (!incrementKg.isFinite || incrementKg <= 0 || incrementKg > 100) {
      throw InvalidValueException('incrementKg', incrementKg);
    }
    if (!incrementLbs.isFinite || incrementLbs <= 0 || incrementLbs > 200) {
      throw InvalidValueException('incrementLbs', incrementLbs);
    }
    if (levelKg != null &&
        (!levelKg.isFinite || levelKg <= 0 || levelKg > 100)) {
      throw InvalidValueException('levelKg', levelKg);
    }
    if (restSec != null && (restSec < 0 || restSec > 3600)) {
      throw InvalidValueException('restSec', restSec);
    }
  }

  /// Warm-up target (1.6.0): a range 1–5 or a bpm value, not both.
  static void _checkTarget(int? range, int? bpm, int? minutes) {
    if (range != null && (range < 1 || range > 5)) {
      throw InvalidValueException('hrTargetRange', range);
    }
    if (bpm != null && (bpm < 40 || bpm > 250)) {
      throw InvalidValueException('hrTargetBpm', bpm);
    }
    if (range != null && bpm != null) {
      throw InvalidValueException('hrTargetBpm', bpm);
    }
    if (minutes != null && (minutes < 1 || minutes > 180)) {
      throw InvalidValueException('hrTargetMinutes', minutes);
    }
  }

  static List<Exercise> _sortedByName(List<Exercise> list) =>
      [...list]..sort((a, b) => compareNames(a.name, b.name));
}
