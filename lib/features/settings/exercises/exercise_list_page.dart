import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings_de.dart';
import '../../../core/router.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../../domain/names.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/exercise_type_icon.dart';
import 'exercise_form_page.dart';

/// Whether [exercise] matches a search [query] (case and umlauts ignored).
bool matchesQuery(Exercise exercise, String query) =>
    query.trim().isEmpty || sortKey(exercise.name).contains(sortKey(query));

/// Settings → Übungen: library with search and category filter.
class ExerciseListPage extends ConsumerStatefulWidget {
  const ExerciseListPage({super.key});

  @override
  ConsumerState<ExerciseListPage> createState() => _ExerciseListPageState();
}

class _ExerciseListPageState extends ConsumerState<ExerciseListPage> {
  String _query = '';
  ExerciseCategory? _category;
  bool _allCategories = true;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(activeExercisesProvider).value;
    final archivedCount = ref.watch(archivedExercisesProvider).value?.length;
    final filtered = all
        ?.where(
          (e) =>
              matchesQuery(e, _query) &&
              (_allCategories || e.category == _category),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.exercisesTitle),
        actions: [
          IconButton(
            tooltip: S.openArchive,
            icon: Badge(
              isLabelVisible: (archivedCount ?? 0) > 0,
              label: Text('${archivedCount ?? 0}'),
              child: const Icon(Icons.inventory_2_outlined),
            ),
            onPressed: () => context.push(AppRoutes.exerciseArchive),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openExerciseForm(context),
        icon: const Icon(Icons.add),
        label: const Text(S.newExercise),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: S.search,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text(S.allCategories),
                  selected: _allCategories,
                  onSelected: (_) => setState(() => _allCategories = true),
                ),
                for (final c in [...ExerciseCategory.values, null])
                  FilterChip(
                    label: Text(S.category(c)),
                    selected: !_allCategories && _category == c,
                    onSelected: (_) => setState(() {
                      _allCategories = false;
                      _category = c;
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: switch (filtered) {
              null => const SizedBox.shrink(),
              [] when all!.isEmpty => const EmptyState(
                icon: Icons.fitness_center,
                message: S.exercisesEmpty,
              ),
              [] => const EmptyState(
                icon: Icons.search_off,
                message: S.exercisesNoMatch,
              ),
              final list => ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final e = list[i];
                  return ListTile(
                    leading: ExerciseTypeIcon(e.type),
                    title: Text(e.name),
                    subtitle: Text(
                      '${S.category(e.category)} · ${S.exerciseType(e.type)}',
                    ),
                    onTap: () => openExerciseForm(context, exercise: e),
                  );
                },
              ),
            },
          ),
        ],
      ),
    );
  }
}
