/// Rest timer (SPEC §6.2.1). The end is always derived from the stored
/// completion time of the last set, so it survives an app restart.
library;

import 'groups.dart';
import 'models/models.dart';

/// How long "Pause vorbei" stays visible.
const restOverDisplay = Duration(seconds: 10);

/// Rest of the session exercise → of the exercise → default.
int restDurationSec({
  required int? sessionExerciseRestSec,
  required int? exerciseRestSec,
  required int defaultRestSec,
}) => sessionExerciseRestSec ?? exerciseRestSec ?? defaultRestSec;

/// The set the rest timer runs for and its duration: the latest set of the
/// session. In a superset only a set that ends a round starts a rest (M9),
/// with the rest of the superset if set. `null` = no rest.
({SetEntry set, int durationSec})? restAfterLatestSet(
  List<SessionExerciseDetail> details,
  Map<int, SessionSuperset> supersets, {
  required int defaultRestSec,
}) {
  SetEntry? latest;
  SessionExerciseDetail? owner;
  for (final d in details) {
    for (final set in d.sets) {
      if (latest == null ||
          set.completedAt.isAfter(latest.completedAt) ||
          (set.completedAt == latest.completedAt && set.id > latest.id)) {
        latest = set;
        owner = d;
      }
    }
  }
  if (latest == null || owner == null) return null;
  final own = restDurationSec(
    sessionExerciseRestSec: owner.sessionExercise.restSec,
    exerciseRestSec: owner.exercise.restSec,
    defaultRestSec: defaultRestSec,
  );
  final supersetId = owner.sessionExercise.supersetId;
  if (supersetId == null) return (set: latest, durationSec: own);
  final members = [
    for (final d in details)
      if (d.sessionExercise.supersetId == supersetId) supersetMemberOf(d),
  ];
  if (members.length < 2) return (set: latest, durationSec: own);
  final step = afterSupersetSet(
    members,
    owner.sessionExercise.id,
    latest.setIndex,
  );
  if (!step.roundEnd) return null;
  return (set: latest, durationSec: supersets[supersetId]?.restSec ?? own);
}

sealed class RestState {
  const RestState();
}

final class RestHidden extends RestState {
  const RestHidden();
}

final class RestRunning extends RestState {
  const RestRunning({required this.remaining, required this.total});

  final Duration remaining;
  final Duration total;

  /// 0 … 1 elapsed share for the progress bar.
  double get progress => total <= Duration.zero
      ? 1
      : (1 - remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
}

final class RestOver extends RestState {
  const RestOver();
}

/// State of the rest after a set completed at [lastSetAt].
/// [adjustSec] are the ±15 s changes made by the user.
RestState restState({
  required DateTime lastSetAt,
  required int durationSec,
  required int adjustSec,
  required DateTime now,
}) {
  final total = Duration(seconds: durationSec + adjustSec);
  final end = lastSetAt.add(total);
  if (now.isBefore(end)) {
    return RestRunning(remaining: end.difference(now), total: total);
  }
  if (now.difference(end) < restOverDisplay) return const RestOver();
  return const RestHidden();
}
