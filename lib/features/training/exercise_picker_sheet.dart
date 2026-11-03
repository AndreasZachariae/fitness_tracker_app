import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/exercise_type_icon.dart';
import '../settings/exercises/exercise_list_page.dart' show matchesQuery;

/// Result of the exercise picker.
sealed class PickerResult {
  const PickerResult();
}

final class PickedExercise extends PickerResult {
  const PickedExercise(this.exercise);

  final Exercise exercise;
}

/// "Neue Übung anlegen", prefilled with the search text.
final class CreateExercise extends PickerResult {
  const CreateExercise(this.initialName);

  final String initialName;
}

/// Bottom sheet "Übung hinzufügen" (SPEC §6.1): search, recently used,
/// library by category. Exercises in [containedIds] are marked and disabled.
Future<PickerResult?> showExercisePicker(
  BuildContext context, {
  required Set<int> containedIds,
}) {
  return showModalBottomSheet<PickerResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _ExercisePicker(containedIds: containedIds),
    ),
  );
}

class _ExercisePicker extends ConsumerStatefulWidget {
  const _ExercisePicker({required this.containedIds});

  final Set<int> containedIds;

  @override
  ConsumerState<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<_ExercisePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(activeExercisesProvider).value ?? const [];
    final recent = ref.watch(recentExercisesProvider).value ?? const [];
    final searching = _query.trim().isNotEmpty;

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    Widget tile(Exercise e) {
      final contained = widget.containedIds.contains(e.id);
      return ListTile(
        enabled: !contained,
        leading: ExerciseTypeIcon(e.type),
        title: Text(e.name),
        subtitle: contained ? const Text(S.alreadyAdded) : null,
        trailing: contained ? const Icon(Icons.check) : null,
        onTap: () => Navigator.of(context).pop(PickedExercise(e)),
      );
    }

    final children = <Widget>[];
    if (searching) {
      children.addAll(all.where((e) => matchesQuery(e, _query)).map(tile));
    } else {
      if (recent.isNotEmpty) {
        children
          ..add(header(S.recentlyUsed))
          ..addAll(recent.map(tile));
      }
      for (final category in [...ExerciseCategory.values, null]) {
        final group = all.where((e) => e.category == category).toList();
        if (group.isEmpty) continue;
        children
          ..add(header(S.category(category)))
          ..addAll(group.map(tile));
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.pickerTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  hintText: S.pickerSearchHint,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: children.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      searching ? S.exercisesNoMatch : S.pickerEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(children: children),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
              icon: const Icon(Icons.add),
              label: const Text(S.createExercise),
              onPressed: () =>
                  Navigator.of(context).pop(CreateExercise(_query.trim())),
            ),
          ),
        ),
      ],
    );
  }
}
