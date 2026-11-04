import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';

/// An exercise of the free training list. Entries with the same
/// [supersetKey] form a superset (M9); [supersetRestSec] is the same for all
/// of its members.
typedef FreeEntry = ({
  int exerciseId,
  ExerciseTargets targets,
  int? supersetKey,
  int? supersetRestSec,
});

FreeEntry _entry(
  int exerciseId,
  ExerciseTargets targets, {
  int? supersetKey,
  int? supersetRestSec,
}) => (
  exerciseId: exerciseId,
  targets: targets,
  supersetKey: supersetKey,
  supersetRestSec: supersetRestSec,
);

FreeEntry _withSuperset(FreeEntry e, int? key, int? restSec) =>
    _entry(e.exerciseId, e.targets, supersetKey: key, supersetRestSec: restSec);

/// The list of the "Frei" mode. Lives only in memory (SPEC §6.1).
class FreeTrainingList extends Notifier<List<FreeEntry>> {
  var _nextKey = 1;

  @override
  List<FreeEntry> build() => const [];

  bool contains(int exerciseId) => state.any((e) => e.exerciseId == exerciseId);

  void add(int exerciseId, ExerciseTargets targets, {int? supersetKey}) {
    if (contains(exerciseId)) return;
    if (supersetKey == null) {
      state = [...state, _entry(exerciseId, targets)];
      return;
    }
    final last = state.lastIndexWhere((e) => e.supersetKey == supersetKey);
    if (last < 0) return add(exerciseId, targets);
    final rest = state[last].supersetRestSec;
    state = [...state]
      ..insert(
        last + 1,
        _entry(
          exerciseId,
          targets,
          supersetKey: supersetKey,
          supersetRestSec: rest,
        ),
      );
  }

  /// Removes an entry and returns its index and value for undo. A superset
  /// left with one exercise is dissolved.
  (int, FreeEntry)? remove(int exerciseId) {
    final index = state.indexWhere((e) => e.exerciseId == exerciseId);
    if (index < 0) return null;
    final entry = state[index];
    state = [...state]..removeAt(index);
    if (entry.supersetKey case final key?) _dissolveIfTooSmall(key);
    return (index, entry);
  }

  /// Puts a removed entry back (undo); a superset dissolved in the
  /// meantime is not restored.
  void insert(int index, FreeEntry entry) {
    if (contains(entry.exerciseId)) return;
    final key = entry.supersetKey;
    final keep = key != null && state.any((e) => e.supersetKey == key);
    state = [...state]
      ..insert(
        index.clamp(0, state.length),
        keep ? entry : _withSuperset(entry, null, null),
      );
  }

  void updateTargets(int exerciseId, ExerciseTargets targets) {
    state = [
      for (final e in state)
        e.exerciseId == exerciseId
            ? _entry(
                e.exerciseId,
                targets,
                supersetKey: e.supersetKey,
                supersetRestSec: e.supersetRestSec,
              )
            : e,
    ];
  }

  /// [newIndex] as from `onReorderItem` (already adjusted).
  void move(int oldIndex, int newIndex) {
    final list = [...state];
    list.insert(newIndex, list.removeAt(oldIndex));
    state = list;
  }

  /// Puts the entries into the order of [exerciseIds] (same set of ids).
  void reorderTo(List<int> exerciseIds) {
    final byId = {for (final e in state) e.exerciseId: e};
    if (exerciseIds.length != byId.length ||
        !exerciseIds.every(byId.containsKey)) {
      return;
    }
    state = [for (final id in exerciseIds) byId[id]!];
  }

  /// Forms a superset of [exerciseIds] (at least two, none in a superset).
  /// They move together to the place of the first one. Returns its key.
  int? createSuperset(List<int> exerciseIds) {
    final chosen = exerciseIds.toSet();
    final members = [
      for (final e in state)
        if (chosen.contains(e.exerciseId)) e,
    ];
    if (members.length < 2 || members.any((e) => e.supersetKey != null)) {
      return null;
    }
    final key = _nextKey++;
    final first = state.indexOf(members.first);
    state = [
      for (final (i, e) in state.indexed)
        if (!chosen.contains(e.exerciseId) && i < first) e,
      for (final e in members) _withSuperset(e, key, null),
      for (final (i, e) in state.indexed)
        if (!chosen.contains(e.exerciseId) && i > first) e,
    ];
    return key;
  }

  void dissolveSuperset(int key) => state = [
    for (final e in state)
      e.supersetKey == key ? _withSuperset(e, null, null) : e,
  ];

  void setSupersetRest(int key, int? restSec) => state = [
    for (final e in state)
      e.supersetKey == key ? _withSuperset(e, key, restSec) : e,
  ];

  /// Takes an exercise out of its superset, right behind it.
  void removeFromSuperset(int exerciseId) {
    final index = state.indexWhere((e) => e.exerciseId == exerciseId);
    if (index < 0) return;
    final entry = state[index];
    final key = entry.supersetKey;
    if (key == null) return;
    final others = [...state]..removeAt(index);
    final last = others.lastIndexWhere((e) => e.supersetKey == key);
    state = others..insert(last + 1, _withSuperset(entry, null, null));
    _dissolveIfTooSmall(key);
  }

  void _dissolveIfTooSmall(int key) {
    if (state.where((e) => e.supersetKey == key).length < 2) {
      dissolveSuperset(key);
    }
  }

  void clear() => state = const [];
}

final freeTrainingProvider =
    NotifierProvider<FreeTrainingList, List<FreeEntry>>(FreeTrainingList.new);
