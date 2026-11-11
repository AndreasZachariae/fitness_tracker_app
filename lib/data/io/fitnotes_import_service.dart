import '../../core/clock.dart';
import '../../domain/fitnotes_import.dart';
import '../../domain/models/models.dart';
import '../../domain/names.dart';
import '../db/database.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/plan_repository.dart';
import '../repositories/repository_exceptions.dart';
import '../repositories/session_repository.dart';

/// What the import created.
typedef FitNotesImportResult = ({int planId, int? sessionId, int newExercises});

/// Turns a [FitNotesWorkout] into GymLog data (1.4.0): new exercises, a plan
/// with the targets and groups of the export and – if wanted – the workout
/// itself as a finished training on its day, so that "Letztes Mal" and the
/// prefill know the weights. Everything in one transaction: on any error
/// nothing is stored.
class FitNotesImportService {
  FitNotesImportService({required this.db, required this.clock});

  final AppDatabase db;
  final Clock clock;

  /// A logged set takes this long in the imported training (the export has
  /// no times).
  static const setSpacing = Duration(minutes: 2);

  /// Start of the imported training on its day (local time).
  static const startHour = 18;

  /// [targets]: per exercise of [workout] the id of an existing GymLog
  /// exercise, or null for a new one.
  Future<FitNotesImportResult> import(
    FitNotesWorkout workout, {
    required String planName,
    required List<int?> targets,
    required bool withTraining,
  }) {
    if (targets.length != workout.exercises.length) {
      throw ArgumentError.value(targets, 'targets');
    }
    final chosen = [for (final t in targets) ?t];
    if (chosen.toSet().length != chosen.length) {
      throw ArgumentError.value(targets, 'targets', 'an exercise twice');
    }
    return db.transaction(() async {
      final exercises = ExerciseRepository(db, clock);
      final plans = PlanRepository(db, clock);

      // 1. Exercises: existing ones checked, new ones created.
      final all = await db.exercisesDao.getAll();
      final taken = {for (final e in all) nameKey(e.name)};
      final ids = <int>[];
      var created = 0;
      for (final (i, source) in workout.exercises.indexed) {
        if (targets[i] case final id?) {
          final existing = all.where((e) => e.id == id).firstOrNull;
          if (existing == null) throw NotFoundException('exercise', id);
          if (!canImportInto(source, existing)) {
            throw InvalidValueException('targets', id);
          }
          ids.add(id);
          continue;
        }
        final name = uniqueImportName(source.name, taken);
        taken.add(nameKey(name));
        ids.add(
          await exercises.create(
            ExerciseDraft(
              name: name,
              type: source.type,
              category: guessCategory(source.name),
            ),
          ),
        );
        created++;
      }

      // 2. The plan with targets and groups.
      final planId = await plans.create(planName);
      final entryIds = <int>[];
      for (final (i, source) in workout.exercises.indexed) {
        entryIds.add(
          await plans.addExercise(
            planId,
            ids[i],
            targetSets: source.targetSets,
            targetReps: source.targetReps,
            targetDurationSec: source.targetDurationSec,
          ),
        );
      }
      for (final group in importGroups(workout)) {
        await plans.createGroup(planId, group.kind, [
          for (final i in group.members) entryIds[i],
        ]);
      }

      // 3. The workout as a finished training on its day.
      int? sessionId;
      if (withTraining) {
        sessionId = await _importTraining(
          workout,
          (await plans.findById(planId))!,
          ids,
        );
      }
      return (planId: planId, sessionId: sessionId, newExercises: created);
    });
  }

  Future<int> _importTraining(
    FitNotesWorkout workout,
    Plan plan,
    List<int> ids,
  ) async {
    final duration = setSpacing * workout.setCount;
    final now = clock.now();
    final day = workout.date;
    var start = day == null
        ? now.subtract(duration)
        : DateTime(day.year, day.month, day.day, startHour).toUtc();
    // Never in the future (an export of today's training).
    if (start.add(duration).isAfter(now)) start = now.subtract(duration);
    final time = FixedClock(start);
    final sessions = SessionRepository(db, time);

    final supersetOf = <int, int>{};
    for (final (key, group) in importGroups(workout).indexed) {
      if (group.kind != PlanGroupKind.superset) continue;
      for (final i in group.members) {
        supersetOf[i] = key;
      }
    }
    final sessionId = await sessions.start(
      plan: plan,
      exercises: [
        for (final (i, source) in workout.exercises.indexed)
          SessionExerciseDraft(
            exerciseId: ids[i],
            targetSets: source.targetSets,
            targetReps: source.targetReps,
            targetDurationSec: source.targetDurationSec,
            supersetKey: supersetOf[i],
          ),
      ],
    );
    final details = await sessions.getDetails(sessionId);
    for (final (i, source) in workout.exercises.indexed) {
      final sessionExerciseId = details[i].sessionExercise.id;
      for (final s in source.sets) {
        time.advance(setSpacing);
        await sessions.addSet(
          sessionExerciseId,
          weightKg: s.weightKg,
          reps: s.reps,
          durationSec: s.durationSec,
        );
      }
    }
    // Rotations move on as after a real training.
    await sessions.finishSession(sessionId, endedAt: time.now());
    return sessionId;
  }
}

/// A group of the plan: positions in [FitNotesWorkout.exercises].
typedef ImportGroup = ({PlanGroupKind kind, List<int> members});

/// Groups of the export with at least two exercises ("Rotate" and "Set",
/// see [groupKindOf]); a group name with one exercise is no group.
List<ImportGroup> importGroups(FitNotesWorkout workout) {
  final byName = <String, List<int>>{};
  final kinds = <String, PlanGroupKind>{};
  for (final (i, e) in workout.exercises.indexed) {
    final kind = e.groupKind;
    if (kind == null) continue;
    final key = nameKey(e.group!);
    byName.putIfAbsent(key, () => []).add(i);
    kinds[key] = kind;
  }
  return [
    for (final MapEntry(:key, value: members) in byName.entries)
      if (members.length >= 2) (kind: kinds[key]!, members: members),
  ];
}

/// The FitNotes name, or with " (FitNotes)" and a number if GymLog already
/// has an exercise of that name (e.g. of another type).
String uniqueImportName(String name, Set<String> takenKeys) {
  String fit(String base, String suffix) {
    final room = maxNameLength - suffix.length;
    final cut = base.length > room ? base.substring(0, room).trimRight() : base;
    return '$cut$suffix';
  }

  final clean = cleanName(name);
  var candidate = fit(clean, '');
  if (!takenKeys.contains(nameKey(candidate))) return candidate;
  candidate = fit(clean, ' (FitNotes)');
  for (var n = 2; takenKeys.contains(nameKey(candidate)); n++) {
    candidate = fit(clean, ' (FitNotes $n)');
  }
  return candidate;
}
