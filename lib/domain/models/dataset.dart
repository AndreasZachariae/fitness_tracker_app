import 'body_weight_entry.dart';
import 'exercise.dart';
import 'group.dart';
import 'heart_rate_sample.dart';
import 'plan.dart';
import 'session.dart';
import 'session_heart_rate.dart';

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
    this.sessionHeartRates = const [],
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

  /// Heart rate of the running training (buffer, 1.5.0/1.5.1).
  final List<HeartRateSample> heartRateSamples;

  /// What is kept of finished trainings' heart rate (1.5.1).
  final List<SessionHeartRate> sessionHeartRates;
}
