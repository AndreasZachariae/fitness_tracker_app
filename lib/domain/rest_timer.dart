/// Rest timer (SPEC §6.2.1). The end is always derived from the stored
/// completion time of the last set, so it survives an app restart.
library;

/// How long "Pause vorbei" stays visible.
const restOverDisplay = Duration(seconds: 10);

/// Rest of the session exercise → of the exercise → default.
int restDurationSec({
  required int? sessionExerciseRestSec,
  required int? exerciseRestSec,
  required int defaultRestSec,
}) => sessionExerciseRestSec ?? exerciseRestSec ?? defaultRestSec;

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
