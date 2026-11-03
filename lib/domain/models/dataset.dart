import 'body_weight_entry.dart';
import 'exercise.dart';
import 'plan.dart';
import 'session.dart';

/// The complete user data except settings, with ids. Used to replace all
/// data at once (demo data now, backup import later).
final class Dataset {
  const Dataset({
    this.exercises = const [],
    this.plans = const [],
    this.planExercises = const [],
    this.sessions = const [],
    this.sessionExercises = const [],
    this.sets = const [],
    this.bodyWeights = const [],
  });

  final List<Exercise> exercises;
  final List<Plan> plans;
  final List<PlanExercise> planExercises;
  final List<Session> sessions;
  final List<SessionExercise> sessionExercises;
  final List<SetEntry> sets;
  final List<BodyWeightEntry> bodyWeights;
}
