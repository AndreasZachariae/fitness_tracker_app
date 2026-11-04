/// Supersets and rotations (M9): list blocks, superset flow, rotation
/// progress and how a session changes a plan's layout. Pure Dart.
library;

import 'models/models.dart';

// ---------------------------------------------------------------------------
// Blocks

/// A contiguous run of list items: one single item or the members of a
/// group (superset or rotation).
final class Block<T> {
  const Block(this.groupId, this.items);

  /// `null` for a single item.
  final int? groupId;
  final List<T> items;

  bool get isGroup => groupId != null;

  T get first => items.first;
}

/// Splits [ordered] into blocks. Consecutive items with the same group form
/// one block; a group that is (wrongly) split stays split instead of being
/// moved.
List<Block<T>> blocksOf<T>(Iterable<T> ordered, int? Function(T) groupOf) {
  final result = <Block<T>>[];
  for (final item in ordered) {
    final g = groupOf(item);
    if (g != null && result.isNotEmpty && result.last.groupId == g) {
      result.last.items.add(item);
    } else {
      result.add(Block(g, [item]));
    }
  }
  return result;
}

List<T> flatten<T>(Iterable<Block<T>> blocks) => [
  for (final b in blocks) ...b.items,
];

/// Moves [oldIndex] to [newIndex] (final index, as from `onReorderItem`).
/// Items that are not [movable] keep their indices; the movable ones fill
/// the remaining places in their new relative order. `null` if the dragged
/// item cannot be moved.
List<T>? reorderKeepingFixed<T>(
  List<T> items,
  int oldIndex,
  int newIndex,
  bool Function(T) movable,
) {
  if (!movable(items[oldIndex])) return null;
  final dragged = [...items];
  dragged.insert(newIndex, dragged.removeAt(oldIndex));
  final moved = dragged.where(movable).toList();
  var next = 0;
  return [for (final item in items) movable(item) ? moved[next++] : item];
}

// ---------------------------------------------------------------------------
// Superset flow (alternating: A1 → B1 → rest → A2 → B2 → rest …)

/// A superset member as seen by the flow.
typedef SupersetMember = ({
  int id,
  SessionExerciseStatus status,
  int sets,
  int targetSets,
});

SupersetMember supersetMemberOf(SessionExerciseDetail d) => (
  id: d.sessionExercise.id,
  status: d.sessionExercise.status,
  sets: d.sets.where((s) => !s.isWarmup).length,
  targetSets: d.sessionExercise.targetSets,
);

/// Whether [m] still has sets to do in this session.
bool hasSetsLeft(SupersetMember m) =>
    (m.status == SessionExerciseStatus.pending ||
        m.status == SessionExerciseStatus.active) &&
    m.sets < m.targetSets;

/// After set number [setIndex] of member [memberId] (already counted in
/// [members], which are in superset order): the member that comes next and
/// whether the set ended a round (then the rest timer runs).
///
/// Within a round the next member after [memberId] that has not done set
/// [setIndex] yet follows without rest. Otherwise the round is over and the
/// first member with sets left starts the next one (`null` = superset done).
({int? nextId, bool roundEnd}) afterSupersetSet(
  List<SupersetMember> members,
  int memberId,
  int setIndex,
) {
  final at = members.indexWhere((m) => m.id == memberId);
  for (final m in members.skip(at + 1)) {
    if (hasSetsLeft(m) && m.sets < setIndex) {
      return (nextId: m.id, roundEnd: false);
    }
  }
  for (final m in members) {
    if (hasSetsLeft(m)) return (nextId: m.id, roundEnd: true);
  }
  return (nextId: null, roundEnd: true);
}

/// The member that follows when [memberId] was skipped or finished early:
/// the next one after it with sets left (wrapping around), else `null`.
int? nextSupersetMember(List<SupersetMember> members, int memberId) {
  final at = members.indexWhere((m) => m.id == memberId);
  for (var i = 1; i <= members.length; i++) {
    final m = members[(at + i) % members.length];
    if (m.id != memberId && hasSetsLeft(m)) return m.id;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Rotation

/// Index of the member due in the next training: [currentExerciseId] if it
/// is still a member, otherwise the first one.
int rotationIndex(List<int> memberExerciseIds, int? currentExerciseId) {
  final i = memberExerciseIds.indexOf(currentExerciseId ?? -1);
  return i < 0 ? 0 : i;
}

/// Progress of a rotation after a finished training of its plan. Moves on
/// only when the due exercise was actually trained (has working sets);
/// after [every] trainings the next member is due.
({int? exerciseId, int done}) advanceRotation({
  required List<int> memberExerciseIds,
  required int? currentExerciseId,
  required int done,
  required int every,
  required bool trained,
}) {
  if (memberExerciseIds.isEmpty) {
    return (exerciseId: currentExerciseId, done: done);
  }
  final i = rotationIndex(memberExerciseIds, currentExerciseId);
  final current = memberExerciseIds[i];
  if (!trained) return (exerciseId: current, done: done);
  if (done + 1 < every) return (exerciseId: current, done: done + 1);
  return (
    exerciseId: memberExerciseIds[(i + 1) % memberExerciseIds.length],
    done: 0,
  );
}

// ---------------------------------------------------------------------------
// Plan layout

/// One block of a plan's exercise list, by exercise ids.
sealed class LayoutBlock {
  const LayoutBlock();
}

final class SingleBlock extends LayoutBlock {
  const SingleBlock(this.exerciseId);

  final int exerciseId;

  @override
  bool operator ==(Object other) =>
      other is SingleBlock && other.exerciseId == exerciseId;

  @override
  int get hashCode => exerciseId.hashCode;

  @override
  String toString() => 'Single($exerciseId)';
}

final class SupersetBlock extends LayoutBlock {
  const SupersetBlock(this.exerciseIds, {this.restSec, this.groupId});

  final List<int> exerciseIds;
  final int? restSec;

  /// Existing plan group to keep, `null` = new group.
  final int? groupId;

  @override
  bool operator ==(Object other) =>
      other is SupersetBlock &&
      other.groupId == groupId &&
      other.restSec == restSec &&
      _sameList(other.exerciseIds, exerciseIds);

  @override
  int get hashCode =>
      Object.hash(groupId, restSec, Object.hashAll(exerciseIds));

  @override
  String toString() => 'Superset($groupId, $exerciseIds, $restSec)';
}

/// A rotation is never changed by a session; it only keeps its place.
final class RotationBlock extends LayoutBlock {
  const RotationBlock(this.groupId, this.exerciseIds);

  final int groupId;
  final List<int> exerciseIds;

  @override
  bool operator ==(Object other) =>
      other is RotationBlock &&
      other.groupId == groupId &&
      _sameList(other.exerciseIds, exerciseIds);

  @override
  int get hashCode => Object.hash(groupId, Object.hashAll(exerciseIds));

  @override
  String toString() => 'Rotation($groupId, $exerciseIds)';
}

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool sameLayout(List<LayoutBlock> a, List<LayoutBlock> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The layout of a plan from its entries (in order) and groups.
List<LayoutBlock> planLayout(
  List<PlanExercise> entries,
  Map<int, PlanGroup> groups,
) {
  final result = <LayoutBlock>[];
  for (final b in blocksOf(entries, (e) => e.groupId)) {
    final ids = [for (final e in b.items) e.exerciseId];
    switch (groups[b.groupId]) {
      case null:
        result.addAll(ids.map(SingleBlock.new));
      case PlanGroup(kind: PlanGroupKind.superset, :final id, :final restSec):
        result.add(SupersetBlock(ids, restSec: restSec, groupId: id));
      case PlanGroup(kind: PlanGroupKind.rotation, :final id):
        result.add(RotationBlock(id, ids));
    }
  }
  return result;
}

/// The layout of a session from its exercises (in order) and supersets.
List<LayoutBlock> sessionLayout(
  List<SessionExercise> exercises,
  Map<int, SessionSuperset> supersets,
) {
  final result = <LayoutBlock>[];
  for (final b in blocksOf(exercises, (e) => e.supersetId)) {
    if (b.isGroup && b.items.length >= 2) {
      result.add(
        SupersetBlock([
          for (final e in b.items) e.exerciseId,
        ], restSec: supersets[b.groupId]?.restSec),
      );
    } else {
      result.addAll([for (final e in b.items) SingleBlock(e.exerciseId)]);
    }
  }
  return result;
}

/// The plan layout after taking over a session (SPEC §6.3 "Reihenfolge und
/// neue Übungen übernehmen", M9 with groups):
///
/// - order and supersets as in the session; a session superset keeps the
///   plan group of its first member if that was a superset of the plan,
/// - a plan rotation stays as it is and takes the place of its exercise
///   in the session (never part of a superset: no nesting),
/// - exercises added during the session are included,
/// - plan exercises missing in the session stay at the end, in plan order.
List<LayoutBlock> adoptedLayout(
  List<LayoutBlock> plan,
  List<LayoutBlock> session,
) {
  final rotationOf = <int, RotationBlock>{};
  final supersetOf = <int, SupersetBlock>{};
  for (final b in plan) {
    switch (b) {
      case RotationBlock():
        for (final e in b.exerciseIds) {
          rotationOf[e] = b;
        }
      case SupersetBlock():
        for (final e in b.exerciseIds) {
          supersetOf[e] = b;
        }
      case SingleBlock():
    }
  }
  final result = <LayoutBlock>[];
  final seen = <int>{};
  final usedGroups = <int>{};

  void addRotation(RotationBlock r) {
    if (usedGroups.add(r.groupId)) {
      result.add(r);
      seen.addAll(r.exerciseIds);
    }
  }

  for (final b in session) {
    switch (b) {
      case SingleBlock(:final exerciseId):
        if (rotationOf[exerciseId] case final r?) {
          addRotation(r);
        } else if (seen.add(exerciseId)) {
          result.add(b);
        }
      case SupersetBlock():
        final members = [
          for (final e in b.exerciseIds)
            if (!rotationOf.containsKey(e) && !seen.contains(e)) e,
        ];
        if (members.length >= 2) {
          final planGroup = supersetOf[members.first]?.groupId;
          final keep = planGroup != null && usedGroups.add(planGroup);
          result.add(
            SupersetBlock(
              members,
              restSec: b.restSec,
              groupId: keep ? planGroup : null,
            ),
          );
        } else {
          result.addAll(members.map(SingleBlock.new));
        }
        seen.addAll(members);
        for (final e in b.exerciseIds) {
          if (rotationOf[e] case final r?) addRotation(r);
        }
      case RotationBlock():
        addRotation(b);
    }
  }

  for (final b in plan) {
    switch (b) {
      case SingleBlock(:final exerciseId):
        if (seen.add(exerciseId)) result.add(b);
      case RotationBlock():
        addRotation(b);
      case SupersetBlock():
        final missing = [
          for (final e in b.exerciseIds)
            if (!seen.contains(e)) e,
        ];
        if (missing.length == b.exerciseIds.length &&
            (b.groupId == null || usedGroups.add(b.groupId!))) {
          result.add(b);
        } else {
          result.addAll(missing.map(SingleBlock.new));
        }
        seen.addAll(missing);
    }
  }
  return result;
}

/// Exercise ids of a layout in list order.
List<int> layoutExerciseIds(List<LayoutBlock> layout) => [
  for (final b in layout)
    ...switch (b) {
      SingleBlock(:final exerciseId) => [exerciseId],
      SupersetBlock(:final exerciseIds) => exerciseIds,
      RotationBlock(:final exerciseIds) => exerciseIds,
    },
];
