import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';

/// An exercise of the free training list.
typedef FreeEntry = ({int exerciseId, ExerciseTargets targets});

/// The list of the "Frei" mode. Lives only in memory (SPEC §6.1).
class FreeTrainingList extends Notifier<List<FreeEntry>> {
  @override
  List<FreeEntry> build() => const [];

  bool contains(int exerciseId) => state.any((e) => e.exerciseId == exerciseId);

  void add(int exerciseId, ExerciseTargets targets) {
    if (contains(exerciseId)) return;
    state = [...state, (exerciseId: exerciseId, targets: targets)];
  }

  /// Removes an entry and returns its index and value for undo.
  (int, FreeEntry)? remove(int exerciseId) {
    final index = state.indexWhere((e) => e.exerciseId == exerciseId);
    if (index < 0) return null;
    final entry = state[index];
    state = [...state]..removeAt(index);
    return (index, entry);
  }

  void insert(int index, FreeEntry entry) {
    if (contains(entry.exerciseId)) return;
    state = [...state]..insert(index.clamp(0, state.length), entry);
  }

  void updateTargets(int exerciseId, ExerciseTargets targets) {
    state = [
      for (final e in state)
        e.exerciseId == exerciseId
            ? (exerciseId: exerciseId, targets: targets)
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

  void clear() => state = const [];
}

final freeTrainingProvider =
    NotifierProvider<FreeTrainingList, List<FreeEntry>>(FreeTrainingList.new);
