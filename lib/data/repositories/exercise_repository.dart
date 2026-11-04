import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../domain/exercise_library.dart';
import '../../domain/models/models.dart';
import '../../domain/names.dart';
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

  /// Number of plans that contain the exercise.
  Future<int> planCount(int id) => _db.exercisesDao.planCount(id);

  /// Creates an exercise and returns its id.
  Future<int> create(ExerciseDraft draft) => _db.transaction(() async {
    final name = await _checkName(draft.name);
    _checkValues(incrementKg: draft.incrementKg, restSec: draft.restSec);
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
    _checkValues(incrementKg: exercise.incrementKg, restSec: exercise.restSec);
    if (exercise.type != existing.type &&
        await _db.exercisesDao.hasSessionHistory(exercise.id)) {
      throw TypeChangeNotAllowedException(exercise.id);
    }
    await _db.exercisesDao.updateExercise(
      exercise.copyWith(name: name, notes: exercise.notes.trim()),
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

  static void _checkValues({required double incrementKg, int? restSec}) {
    if (!incrementKg.isFinite || incrementKg <= 0 || incrementKg > 100) {
      throw InvalidValueException('incrementKg', incrementKg);
    }
    if (restSec != null && (restSec < 0 || restSec > 3600)) {
      throw InvalidValueException('restSec', restSec);
    }
  }

  static List<Exercise> _sortedByName(List<Exercise> list) =>
      [...list]..sort((a, b) => compareNames(a.name, b.name));
}
