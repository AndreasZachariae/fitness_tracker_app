import 'groups.dart';
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
) => reorderKeepingFixed(
  ordered,
  oldIndex,
  newIndex,
  (e) => isMovable(e.status),
)?.map((e) => e.id).toList();

/// New order of session exercise ids after dragging block [oldIndex] to
/// [newIndex] among the blocks (singles and supersets, M9). A block is
/// movable when all its exercises are; fixed blocks keep their places.
List<int>? reorderSessionBlocks(
  List<Block<SessionExercise>> blocks,
  int oldIndex,
  int newIndex,
) => reorderKeepingFixed(
  blocks,
  oldIndex,
  newIndex,
  (b) => b.items.every((e) => isMovable(e.status)),
)?.expand((b) => b.items.map((e) => e.id)).toList();

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
