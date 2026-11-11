import 'body_weight_entry.dart';
import 'exercise.dart';
import 'group.dart';
import 'heart_rate_sample.dart';
import 'plan.dart';
import 'session.dart';

/// The complete user data except settings, with ids. Used to replace all
/// data at once (demo data now, backup import later).
final class Dataset {
  const Dataset({
    this.exercises = const [],
    this.plans = const [],
    this.planExercises = const [],
    this.planGroups = const [],
    this.planSchedules = const [],
    this.sessions = const [],
    this.sessionExercises = const [],
    this.sessionSupersets = const [],
    this.sets = const [],
    this.bodyWeights = const [],
    this.heartRateSamples = const [],
  });

  final List<Exercise> exercises;
  final List<Plan> plans;
  final List<PlanExercise> planExercises;
  final List<PlanGroup> planGroups;
  final List<PlanScheduleEntry> planSchedules;
  final List<Session> sessions;
  final List<SessionExercise> sessionExercises;
  final List<SessionSuperset> sessionSupersets;
  final List<SetEntry> sets;
  final List<BodyWeightEntry> bodyWeights;

  /// Heart rate during trainings (1.5.0).
  final List<HeartRateSample> heartRateSamples;
}
