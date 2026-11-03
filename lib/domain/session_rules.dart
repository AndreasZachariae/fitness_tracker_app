import 'models/models.dart';

/// A session counts as forgotten after this time (SPEC §6.2).
const forgottenSessionAge = Duration(hours: 12);

/// End time when a forgotten session is finished: last set + 5 minutes,
/// without sets the start time (SPEC §6.2).
DateTime forgottenSessionEnd(Session session, DateTime? lastSetAt) =>
    lastSetAt == null
    ? session.startedAt
    : lastSetAt.add(const Duration(minutes: 5));

bool isForgottenSession(Session session, DateTime now) =>
    session.isActive && now.difference(session.startedAt) > forgottenSessionAge;

/// Only open and active exercises can be moved during a session.
bool isMovable(SessionExerciseStatus status) =>
    status == SessionExerciseStatus.pending ||
    status == SessionExerciseStatus.active;

/// New order of session exercise ids after dragging [oldIndex] to
/// [newIndex] (final index, as from `onReorderItem`).
///
/// Done and skipped exercises keep their places; the movable ones fill the
/// remaining places in their new relative order. Returns `null` if the
/// dragged exercise cannot be moved.
List<int>? reorderSessionExercises(
  List<SessionExercise> ordered,
  int oldIndex,
  int newIndex,
) {
  if (!isMovable(ordered[oldIndex].status)) return null;
  final dragged = [...ordered];
  dragged.insert(newIndex, dragged.removeAt(oldIndex));
  final movable = [
    for (final e in dragged)
      if (isMovable(e.status)) e.id,
  ];
  var next = 0;
  return [
    for (final e in ordered) isMovable(e.status) ? movable[next++] : e.id,
  ];
}

/// The open exercise that comes next after [afterId] (wrapping around), or
/// the first open one. `null` if nothing is open.
int? nextPendingExercise(List<SessionExercise> ordered, {int? afterId}) {
  final pending = [
    for (final (i, e) in ordered.indexed)
      if (e.status == SessionExerciseStatus.pending) (i, e.id),
  ];
  if (pending.isEmpty) return null;
  final start = afterId == null
      ? -1
      : ordered.indexWhere((e) => e.id == afterId);
  for (final (i, id) in pending) {
    if (i > start) return id;
  }
  return pending.first.$2;
}

/// Whether finishing a plan session changed the plan: other order of the
/// plan's exercises or exercises added during the session.
bool sessionChangesPlan({
  required List<int> planExerciseIds,
  required List<int> sessionExerciseIds,
}) {
  final inPlan = planExerciseIds.toSet();
  if (sessionExerciseIds.any((id) => !inPlan.contains(id))) return true;
  final sessionOrder = sessionExerciseIds.where(inPlan.contains).toList();
  final planOrder = planExerciseIds
      .where(sessionExerciseIds.toSet().contains)
      .toList();
  for (var i = 0; i < sessionOrder.length; i++) {
    if (sessionOrder[i] != planOrder[i]) return true;
  }
  return false;
}
