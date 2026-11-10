import 'metrics.dart';
import 'models/models.dart';

/// Why a start/end change of a finished session is rejected.
enum SessionTimesError {
  /// The end is not after the start.
  endBeforeStart,

  /// The end lies in the future.
  inFuture,
}

/// Checks new start and end times of a finished session (SPEC §6.4).
SessionTimesError? validateSessionTimes({
  required DateTime start,
  required DateTime end,
  required DateTime now,
}) {
  if (!end.isAfter(start)) return SessionTimesError.endBeforeStart;
  if (end.isAfter(now)) return SessionTimesError.inFuture;
  return null;
}

/// One finished session in the history list.
final class SessionSummary {
  const SessionSummary({
    required this.session,
    required this.setCount,
    required this.volume,
    required this.hasRecords,
    this.volumeChange,
  });

  final Session session;
  final int setCount;

  /// Volume against the previous training of the same plan in percent, as
  /// in the summary (1.3.1); null without one.
  final double? volumeChange;

  /// Σ weight × reps of `weight_reps` working sets (SPEC §7.6).
  final double volume;
  final bool hasRecords;

  Duration get duration => session.endedAt!.difference(session.startedAt);
}

/// For each finished session (any order): the volume change in percent
/// against the previous finished session of the same plan – the same
/// comparison as the summary after a training (SPEC §6.3). Sessions without
/// plan, the first of a plan and those after a session without volume have
/// none.
Map<int, double> planVolumeChanges(
  Iterable<Session> sessions,
  Map<int, double> volume,
) {
  final byPlan = <int, List<Session>>{};
  for (final s in sessions) {
    if (s.planId case final plan? when s.endedAt != null) {
      byPlan.putIfAbsent(plan, () => []).add(s);
    }
  }
  final result = <int, double>{};
  for (final list in byPlan.values) {
    list.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    for (var i = 1; i < list.length; i++) {
      final change = percentChange(
        volume[list[i].id] ?? 0,
        volume[list[i - 1].id],
      );
      if (change != null) result[list[i].id] = change;
    }
  }
  return result;
}

/// Groups [items] (newest first) by local month, keeping the order.
List<(DateTime month, List<T> items)> groupByMonth<T>(
  List<T> items,
  DateTime Function(T) time,
) {
  final result = <(DateTime, List<T>)>[];
  for (final item in items) {
    final local = time(item).toLocal();
    final month = DateTime(local.year, local.month);
    if (result.isEmpty || result.last.$1 != month) result.add((month, []));
    result.last.$2.add(item);
  }
  return result;
}
