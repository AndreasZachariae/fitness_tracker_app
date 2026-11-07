import 'models/models.dart';
import 'weight_steps.dart';

/// Working sets only (SPEC §7).
Iterable<SetEntry> workingSets(Iterable<SetEntry> sets) =>
    sets.where((s) => !s.isWarmup);

/// Volume Σ weight × reps of working sets of `weight_reps` exercises
/// (SPEC §7.6); levels without kg are left out (1.1.0).
double sessionVolume(Iterable<SessionExerciseDetail> details) {
  var sum = 0.0;
  for (final d in details) {
    if (d.exercise.type != ExerciseType.weightReps) continue;
    if (!storesKg(d.exercise)) continue;
    for (final s in workingSets(d.sets)) {
      sum += (s.weightKg ?? 0) * (s.reps ?? 0);
    }
  }
  return sum;
}

/// Change from [previous] to [current] in percent; `null` without a
/// usable previous value.
double? percentChange(double current, double? previous) =>
    previous == null || previous <= 0
    ? null
    : (current - previous) / previous * 100;

/// The best set for a short summary: heaviest (then most reps) for
/// `weight_reps`; most reps (then heaviest) for `bodyweight`; longest for
/// `timed`.
SetEntry? bestSet(ExerciseType type, Iterable<SetEntry> sets) {
  SetEntry? best;
  for (final s in workingSets(sets)) {
    if (best == null || _better(type, s, best)) best = s;
  }
  return best;
}

bool _better(ExerciseType type, SetEntry a, SetEntry b) {
  final (aw, bw) = (a.weightKg ?? 0, b.weightKg ?? 0);
  final (ar, br) = (a.reps ?? 0, b.reps ?? 0);
  return switch (type) {
    ExerciseType.weightReps => aw > bw || (aw == bw && ar > br),
    ExerciseType.bodyweight => ar > br || (ar == br && aw > bw),
    ExerciseType.timed => (a.durationSec ?? 0) > (b.durationSec ?? 0),
  };
}
