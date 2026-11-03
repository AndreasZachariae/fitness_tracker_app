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
  });

  final Session session;
  final int setCount;

  /// Σ weight × reps of `weight_reps` working sets (SPEC §7.6).
  final double volume;
  final bool hasRecords;

  Duration get duration => session.endedAt!.difference(session.startedAt);
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
