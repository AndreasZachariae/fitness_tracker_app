import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../domain/groups.dart';
import '../../domain/models/models.dart';
import '../../domain/names.dart';
import '../db/database.dart';
import '../db/storage_time.dart';
import 'repository_exceptions.dart';

/// Allowed range of target sets in a plan (SPEC §5).
const minTargetSets = 1;
const maxTargetSets = 10;

/// Training plans and their exercises.
class PlanRepository {
  PlanRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// All plans in chip order.
  Stream<List<Plan>> watchPlans() => _db.plansDao.watchPlans();

  Future<List<Plan>> getPlans() => _db.plansDao.getPlans();

  Future<Plan?> findById(int id) => _db.plansDao.findById(id);

  /// Training days of all plans (1.2.0).
  Stream<List<PlanScheduleEntry>> watchAllSchedules() =>
      _db.plansDao.watchAllSchedules();

  Future<List<PlanScheduleEntry>> getSchedules(int planId) =>
      _db.plansDao.getSchedules(planId);

  Future<List<PlanScheduleEntry>> getAllSchedules() =>
      _db.plansDao.getAllSchedules();

  /// Sets the training days of a plan: weekday (1 = Monday … 7 = Sunday) →
  /// local time in minutes after midnight (1.2.0).
  Future<void> setSchedule(int planId, Map<int, int> days) =>
      _db.transaction(() async {
        if (await _db.plansDao.findById(planId) == null) {
          throw NotFoundException('plan', planId);
        }
        for (final MapEntry(key: day, value: minute) in days.entries) {
          if (day < 1 || day > 7) throw InvalidValueException('weekday', day);
          if (minute < 0 || minute >= 24 * 60) {
            throw InvalidValueException('minuteOfDay', minute);
          }
        }
        await _db.plansDao.replaceSchedules(planId, days);
      });

  /// Marks a plan as currently trained or not (1.2.0).
  Future<void> setActive(int planId, bool active) => _db.transaction(() async {
    final plan = await _db.plansDao.findById(planId);
    if (plan == null) throw NotFoundException('plan', planId);
    await _db.plansDao.updatePlan(plan.copyWith(active: active));
  });

  /// Exercises of a plan in order.
  Stream<List<PlanEntry>> watchEntries(int planId) =>
      _db.plansDao.watchEntries(planId);

  Future<List<PlanEntry>> getEntries(int planId) =>
      _db.plansDao.getEntries(planId);

  /// Number of exercises per plan id.
  Stream<Map<int, int>> watchEntryCounts() => _db.plansDao.watchEntryCounts();

  /// Creates an empty plan at the end and returns its id.
  Future<int> create(String name) => _db.transaction(() async {
    final cleaned = await _checkName(name);
    return _db.plansDao.insertPlan(
      PlansCompanion.insert(
        name: cleaned,
        position: await _db.plansDao.nextPlanPosition(),
        createdAt: storageTime(_clock.now()),
      ),
    );
  });

  Future<void> rename(int id, String name) => _db.transaction(() async {
    final plan = await _require(id);
    final cleaned = await _checkName(name, excludeId: id);
    await _db.plansDao.updatePlan(plan.copyWith(name: cleaned));
  });

  /// Copies a plan with all exercises and targets; returns the new id.
  Future<int> duplicate(int id, String newName) => _db.transaction(() async {
    await _require(id);
    final newId = await create(newName);
    final groupIds = <int, int>{};
    for (final g in await _db.plansDao.getGroups(id)) {
      groupIds[g.id] = await _db.plansDao.insertGroup(
        PlanGroupsCompanion.insert(
          planId: newId,
          kind: g.kind,
          restSec: Value(g.restSec),
          rotationEvery: Value(g.rotationEvery),
          rotationExerciseId: Value(g.rotationExerciseId),
          rotationDone: Value(g.rotationDone),
        ),
      );
    }
    for (final entry in await _db.plansDao.getEntries(id)) {
      final p = entry.planExercise;
      await _db.plansDao.insertEntry(
        PlanExercisesCompanion.insert(
          planId: newId,
          exerciseId: p.exerciseId,
          position: p.position,
          targetSets: p.targetSets,
          targetReps: Value(p.targetReps),
          targetDurationSec: Value(p.targetDurationSec),
          restSec: Value(p.restSec),
          groupId: Value(groupIds[p.groupId]),
        ),
      );
    }
    return newId;
  });

  /// Deletes the plan and its exercise list. Past sessions keep their
  /// `planNameSnapshot` (SPEC §5).
  Future<void> delete(int id) => _db.transaction(() async {
    await _require(id);
    await _db.plansDao.deleteById(id);
  });

  /// Sets the chip order; [planIds] must contain every plan exactly once.
  Future<void> reorder(List<int> planIds) => _db.transaction(() async {
    final current = (await _db.plansDao.getPlans()).map((p) => p.id).toSet();
    if (!_isPermutation(planIds, current)) {
      throw InvalidValueException('planIds', planIds);
    }
    for (var i = 0; i < planIds.length; i++) {
      await _db.plansDao.setPlanPosition(planIds[i], i);
    }
  });

  /// Adds an exercise at the end of a plan; returns the new entry id.
  Future<int> addExercise(
    int planId,
    int exerciseId, {
    required int targetSets,
    int? targetReps,
    int? targetDurationSec,
    int? restSec,
  }) => _db.transaction(() async {
    await _require(planId);
    final exercise = await _db.exercisesDao.findById(exerciseId);
    if (exercise == null) throw NotFoundException('exercise', exerciseId);
    _checkTargets(targetSets, targetReps, targetDurationSec, restSec);
    if (await _db.plansDao.containsExercise(planId, exerciseId)) {
      throw DuplicateExerciseException(exerciseId);
    }
    return _db.plansDao.insertEntry(
      PlanExercisesCompanion.insert(
        planId: planId,
        exerciseId: exerciseId,
        position: await _db.plansDao.nextEntryPosition(planId),
        targetSets: targetSets,
        targetReps: Value(targetReps),
        targetDurationSec: Value(targetDurationSec),
        restSec: Value(restSec),
      ),
    );
  });

  /// Saves targets of a plan entry (plan, exercise and position unchanged).
  Future<void> updateEntry(PlanExercise entry) => _db.transaction(() async {
    final existing = await _db.plansDao.findEntry(entry.id);
    if (existing == null) throw NotFoundException('planExercise', entry.id);
    _checkTargets(
      entry.targetSets,
      entry.targetReps,
      entry.targetDurationSec,
      entry.restSec,
    );
    await _db.plansDao.updateEntry(
      existing.copyWith(
        targetSets: entry.targetSets,
        targetReps: entry.targetReps,
        targetDurationSec: entry.targetDurationSec,
        restSec: entry.restSec,
      ),
    );
  });

  /// Removes an exercise from a plan and returns the removed entry.
  Future<PlanExercise> removeEntry(int entryId) => _db.transaction(() async {
    final existing = await _db.plansDao.findEntry(entryId);
    if (existing == null) throw NotFoundException('planExercise', entryId);
    await _db.plansDao.deleteEntry(entryId);
    if (existing.groupId case final groupId?) {
      await _deleteGroupIfEmpty(existing.planId, groupId);
    }
    return existing;
  });

  /// Puts a removed entry back with its id, targets and position (undo).
  Future<void> restoreEntry(PlanExercise entry) => _db.transaction(() async {
    await _require(entry.planId);
    if (await _db.exercisesDao.findById(entry.exerciseId) == null) {
      throw NotFoundException('exercise', entry.exerciseId);
    }
    if (await _db.plansDao.containsExercise(entry.planId, entry.exerciseId)) {
      throw DuplicateExerciseException(entry.exerciseId);
    }
    final groupId = entry.groupId;
    final keepGroup =
        groupId != null && await _db.plansDao.findGroup(groupId) != null;
    await _db.plansDao.insertEntryWithId(
      keepGroup ? entry : entry.copyWith(groupId: null),
    );
  });

  /// Sets the order of a plan's exercises; [entryIds] must contain every
  /// entry of the plan exactly once.
  Future<void> reorderEntries(int planId, List<int> entryIds) =>
      _db.transaction(() async {
        final entries = {
          for (final e in await _db.plansDao.getEntries(planId))
            e.planExercise.id: e.planExercise,
        };
        if (!_isPermutation(entryIds, entries.keys.toSet()) ||
            !_groupsContiguous([for (final id in entryIds) entries[id]!])) {
          throw InvalidValueException('entryIds', entryIds);
        }
        for (var i = 0; i < entryIds.length; i++) {
          await _db.plansDao.setEntryPosition(entryIds[i], i);
        }
      });

  /// Whether taking over [details] (with the session's [supersets]) would
  /// change the plan (SPEC §6.3, M9 with groups).
  Future<bool> sessionChangesPlan(
    int planId,
    List<SessionExerciseDetail> details,
    Map<int, SessionSuperset> supersets,
  ) async {
    final current = await _layoutOf(planId);
    final adopted = adoptedLayout(
      current,
      sessionLayout([for (final d in details) d.sessionExercise], supersets),
    );
    return !sameLayout(current, adopted);
  }

  /// Takes over the order, the supersets and the exercises added during a
  /// finished session (SPEC §6.3). Rotations keep their exercises; plan
  /// exercises not in the session stay at the end.
  Future<void> adoptSession(
    int planId,
    List<SessionExerciseDetail> details, [
    Map<int, SessionSuperset> supersets = const {},
  ]) => _db.transaction(() async {
    await _require(planId);
    final layout = adoptedLayout(
      await _layoutOf(planId),
      sessionLayout([for (final d in details) d.sessionExercise], supersets),
    );
    await _applyLayout(planId, layout, details);
  });

  /// "Als Plan speichern": a new plan with the session's exercises, targets
  /// and supersets in session order. Returns the plan id.
  Future<int> createFromSession(
    String name,
    List<SessionExerciseDetail> details, [
    Map<int, SessionSuperset> supersets = const {},
  ]) => _db.transaction(() async {
    final planId = await create(name);
    final layout = sessionLayout([
      for (final d in details) d.sessionExercise,
    ], supersets);
    await _applyLayout(planId, layout, details);
    return planId;
  });

  Future<List<LayoutBlock>> _layoutOf(int planId) async => planLayout(
    [for (final e in await _db.plansDao.getEntries(planId)) e.planExercise],
    {for (final g in await _db.plansDao.getGroups(planId)) g.id: g},
  );

  /// Writes [layout] to the plan: positions, group membership, new entries
  /// (targets from [details]) and superset groups; groups no longer used
  /// are deleted.
  Future<void> _applyLayout(
    int planId,
    List<LayoutBlock> layout,
    List<SessionExerciseDetail> details,
  ) async {
    final byExercise = {
      for (final e in await _db.plansDao.getEntries(planId))
        e.exercise.id: e.planExercise,
    };
    final fromSession = {for (final d in details) d.exercise.id: d};
    final used = <int>{};
    var position = 0;

    Future<void> place(int exerciseId, int? groupId) async {
      final entry = byExercise[exerciseId];
      if (entry == null) {
        final d = fromSession[exerciseId];
        if (d == null) return;
        await _db.plansDao.insertEntry(
          _entryFromSession(planId, d, position++, groupId),
        );
        return;
      }
      if (entry.position != position || entry.groupId != groupId) {
        await _db.plansDao.updateEntry(
          entry.copyWith(position: position, groupId: groupId),
        );
      }
      position++;
    }

    for (final block in layout) {
      switch (block) {
        case SingleBlock(:final exerciseId):
          await place(exerciseId, null);
        case RotationBlock(:final groupId, :final exerciseIds):
          used.add(groupId);
          for (final e in exerciseIds) {
            await place(e, groupId);
          }
        case SupersetBlock(:final exerciseIds, :final restSec, :final groupId):
          final int id;
          if (groupId != null) {
            final g = (await _db.plansDao.findGroup(groupId))!;
            if (g.restSec != restSec) {
              await _db.plansDao.updateGroup(g.copyWith(restSec: restSec));
            }
            id = groupId;
          } else {
            id = await _db.plansDao.insertGroup(
              PlanGroupsCompanion.insert(
                planId: planId,
                kind: PlanGroupKind.superset,
                restSec: Value(restSec),
              ),
            );
          }
          used.add(id);
          for (final e in exerciseIds) {
            await place(e, id);
          }
      }
    }
    for (final g in await _db.plansDao.getGroups(planId)) {
      if (!used.contains(g.id)) await _db.plansDao.deleteGroup(g.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Groups: supersets and rotations (M9)

  Stream<Map<int, PlanGroup>> watchGroups(int planId) => _db.plansDao
      .watchGroups(planId)
      .map((list) => {for (final g in list) g.id: g});

  Future<Map<int, PlanGroup>> getGroups(int planId) async => {
    for (final g in await _db.plansDao.getGroups(planId)) g.id: g,
  };

  /// Groups the given entries of a plan (at least two, none grouped yet).
  /// The members keep their relative order and move together to the place
  /// of the first one. A rotation starts with its first member.
  Future<int> createGroup(
    int planId,
    PlanGroupKind kind,
    List<int> entryIds, {
    int? restSec,
    int rotationEvery = 1,
  }) => _db.transaction(() async {
    await _require(planId);
    final entries = [
      for (final e in await _db.plansDao.getEntries(planId)) e.planExercise,
    ];
    final chosen = entryIds.toSet();
    final members = [
      for (final e in entries)
        if (chosen.contains(e.id)) e,
    ];
    if (chosen.length < 2 ||
        members.length != chosen.length ||
        members.any((e) => e.groupId != null)) {
      throw InvalidValueException('entryIds', entryIds);
    }
    _checkGroupValues(restSec, rotationEvery);
    final groupId = await _db.plansDao.insertGroup(
      PlanGroupsCompanion.insert(
        planId: planId,
        kind: kind,
        restSec: Value(kind == PlanGroupKind.superset ? restSec : null),
        rotationEvery: Value(rotationEvery),
        rotationExerciseId: Value(
          kind == PlanGroupKind.rotation ? members.first.exerciseId : null,
        ),
      ),
    );
    final firstIndex = entries.indexOf(members.first);
    final rest = [
      for (final e in entries)
        if (!chosen.contains(e.id)) e,
    ];
    final before = rest.where((e) => entries.indexOf(e) < firstIndex);
    final after = rest.where((e) => entries.indexOf(e) > firstIndex);
    final ordered = [...before, ...members, ...after];
    for (final (i, e) in ordered.indexed) {
      final groupOf = chosen.contains(e.id) ? groupId : e.groupId;
      if (e.position != i || e.groupId != groupOf) {
        await _db.plansDao.updateEntry(
          e.copyWith(position: i, groupId: groupOf),
        );
      }
    }
    return groupId;
  });

  /// Dissolves a group; its exercises stay in the plan at their places.
  Future<void> dissolveGroup(int groupId) => _db.transaction(() async {
    final group = await _requireGroup(groupId);
    for (final e in await _db.plansDao.getEntries(group.planId)) {
      if (e.planExercise.groupId == groupId) {
        await _db.plansDao.setEntryGroup(e.planExercise.id, null);
      }
    }
    await _db.plansDao.deleteGroup(groupId);
  });

  /// Saves rest (superset) and "change after N trainings" (rotation).
  Future<void> updateGroup(PlanGroup group) => _db.transaction(() async {
    final existing = await _requireGroup(group.id);
    _checkGroupValues(group.restSec, group.rotationEvery);
    await _db.plansDao.updateGroup(
      existing.copyWith(
        restSec: group.restSec,
        rotationEvery: group.rotationEvery,
        rotationDone: existing.rotationDone.clamp(0, group.rotationEvery - 1),
      ),
    );
  });

  /// Makes [exerciseId] the exercise due in the next training of the
  /// rotation (counter restarts).
  Future<void> setRotationCurrent(int groupId, int exerciseId) =>
      _db.transaction(() async {
        final group = await _requireGroup(groupId);
        if (group.kind != PlanGroupKind.rotation) {
          throw InvalidValueException('groupId', groupId);
        }
        final members = await _memberEntries(group);
        if (!members.any((e) => e.exerciseId == exerciseId)) {
          throw InvalidValueException('exerciseId', exerciseId);
        }
        await _db.plansDao.updateGroup(
          group.copyWith(rotationExerciseId: exerciseId, rotationDone: 0),
        );
      });

  /// Moves a single entry of the plan into a group (at its end).
  Future<void> addToGroup(int groupId, int entryId) =>
      _db.transaction(() async {
        final group = await _requireGroup(groupId);
        final entry = await _db.plansDao.findEntry(entryId);
        if (entry == null) throw NotFoundException('planExercise', entryId);
        if (entry.planId != group.planId || entry.groupId != null) {
          throw InvalidValueException('entryId', entryId);
        }
        await _moveIntoGroupEnd(group, entry);
      });

  /// Adds a new exercise to the plan directly into a group (at its end).
  Future<int> addExerciseToGroup(
    int groupId,
    int exerciseId,
    ExerciseTargets targets,
  ) => _db.transaction(() async {
    final group = await _requireGroup(groupId);
    final id = await addExercise(
      group.planId,
      exerciseId,
      targetSets: targets.sets,
      targetReps: targets.reps,
      targetDurationSec: targets.durationSec,
      restSec: targets.restSec,
    );
    await _moveIntoGroupEnd(group, (await _db.plansDao.findEntry(id))!);
    return id;
  });

  /// Takes an entry out of its group and puts it right after the group. A
  /// group left with fewer than two exercises is dissolved.
  Future<void> removeFromGroup(int entryId) => _db.transaction(() async {
    final entry = await _db.plansDao.findEntry(entryId);
    if (entry == null) throw NotFoundException('planExercise', entryId);
    final groupId = entry.groupId;
    if (groupId == null) return;
    final entries = [
      for (final e in await _db.plansDao.getEntries(entry.planId))
        e.planExercise,
    ];
    final others = [
      for (final e in entries)
        if (e.id != entryId) e,
    ];
    final lastMember = others.lastIndexWhere((e) => e.groupId == groupId);
    final ordered = [...others]
      ..insert(lastMember + 1, entry.copyWith(groupId: null));
    await _writeOrder(ordered, entries);
    final remaining = others.where((e) => e.groupId == groupId).length;
    if (remaining < 2) await dissolveGroup(groupId);
  });

  Future<void> _moveIntoGroupEnd(PlanGroup group, PlanExercise entry) async {
    final entries = [
      for (final e in await _db.plansDao.getEntries(group.planId))
        e.planExercise,
    ];
    final others = [
      for (final e in entries)
        if (e.id != entry.id) e,
    ];
    final lastMember = others.lastIndexWhere((e) => e.groupId == group.id);
    final ordered = [...others]
      ..insert(lastMember + 1, entry.copyWith(groupId: group.id));
    await _writeOrder(ordered, entries);
    if (group.kind == PlanGroupKind.rotation &&
        group.rotationExerciseId == null) {
      await _db.plansDao.updateGroup(
        group.copyWith(
          rotationExerciseId: ordered
              .firstWhere((e) => e.groupId == group.id)
              .exerciseId,
        ),
      );
    }
  }

  /// Writes positions and group ids of [ordered] where they changed.
  Future<void> _writeOrder(
    List<PlanExercise> ordered,
    List<PlanExercise> before,
  ) async {
    final old = {for (final e in before) e.id: e};
    for (final (i, e) in ordered.indexed) {
      final o = old[e.id]!;
      if (o.position != i || o.groupId != e.groupId) {
        await _db.plansDao.updateEntry(
          o.copyWith(position: i, groupId: e.groupId),
        );
      }
    }
  }

  Future<List<PlanExercise>> _memberEntries(PlanGroup group) async => [
    for (final e in await _db.plansDao.getEntries(group.planId))
      if (e.planExercise.groupId == group.id) e.planExercise,
  ];

  Future<void> _deleteGroupIfEmpty(int planId, int groupId) async {
    final group = await _db.plansDao.findGroup(groupId);
    if (group == null) return;
    if ((await _memberEntries(group)).isEmpty) {
      await _db.plansDao.deleteGroup(groupId);
    }
  }

  Future<PlanGroup> _requireGroup(int id) async {
    final group = await _db.plansDao.findGroup(id);
    if (group == null) throw NotFoundException('planGroup', id);
    return group;
  }

  static void _checkGroupValues(int? restSec, int rotationEvery) {
    if (restSec != null && (restSec < 0 || restSec > 3600)) {
      throw InvalidValueException('restSec', restSec);
    }
    if (rotationEvery < minRotationEvery || rotationEvery > maxRotationEvery) {
      throw InvalidValueException('rotationEvery', rotationEvery);
    }
  }

  static bool _groupsContiguous(List<PlanExercise> ordered) {
    final closed = <int>{};
    int? open;
    for (final e in ordered) {
      if (e.groupId != open) {
        if (open != null) closed.add(open);
        if (e.groupId != null && closed.contains(e.groupId)) return false;
        open = e.groupId;
      }
    }
    return true;
  }

  static PlanExercisesCompanion _entryFromSession(
    int planId,
    SessionExerciseDetail d,
    int position, [
    int? groupId,
  ]) {
    final se = d.sessionExercise;
    return PlanExercisesCompanion.insert(
      planId: planId,
      exerciseId: d.exercise.id,
      position: position,
      targetSets: se.targetSets.clamp(minTargetSets, maxTargetSets),
      targetReps: Value(se.targetReps),
      targetDurationSec: Value(se.targetDurationSec),
      restSec: Value(se.restSec),
      groupId: Value(groupId),
    );
  }

  Future<Plan> _require(int id) async {
    final plan = await _db.plansDao.findById(id);
    if (plan == null) throw NotFoundException('plan', id);
    return plan;
  }

  Future<String> _checkName(String input, {int? excludeId}) async {
    if (!isValidName(input)) throw InvalidNameException(input);
    final key = nameKey(input);
    final all = await _db.plansDao.getPlans();
    if (all.any((p) => p.id != excludeId && nameKey(p.name) == key)) {
      throw DuplicateNameException(cleanName(input));
    }
    return cleanName(input);
  }

  static void _checkTargets(
    int targetSets,
    int? targetReps,
    int? targetDurationSec,
    int? restSec,
  ) {
    if (targetSets < minTargetSets || targetSets > maxTargetSets) {
      throw InvalidValueException('targetSets', targetSets);
    }
    if (targetReps != null && targetReps < 1) {
      throw InvalidValueException('targetReps', targetReps);
    }
    if (targetDurationSec != null && targetDurationSec < 1) {
      throw InvalidValueException('targetDurationSec', targetDurationSec);
    }
    if (restSec != null && (restSec < 0 || restSec > 3600)) {
      throw InvalidValueException('restSec', restSec);
    }
  }

  static bool _isPermutation(List<int> ids, Set<int> expected) =>
      ids.length == expected.length && ids.toSet().containsAll(expected);
}
