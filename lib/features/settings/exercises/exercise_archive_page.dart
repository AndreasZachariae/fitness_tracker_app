import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings_de.dart';
import '../../../data/providers.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/exercise_type_icon.dart';
import '../../../widgets/snackbars.dart';

/// Archived exercises with "Wiederherstellen".
class ExerciseArchivePage extends ConsumerWidget {
  const ExerciseArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(archivedExercisesProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text(S.archiveTitle)),
      body: switch (archived) {
        null => const SizedBox.shrink(),
        [] => const EmptyState(
          icon: Icons.inventory_2_outlined,
          message: S.archiveEmpty,
        ),
        final list => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final e = list[i];
            return ListTile(
              leading: ExerciseTypeIcon(e.type),
              title: Text(e.name),
              subtitle: Text(S.category(e.category)),
              trailing: TextButton(
                onPressed: () async {
                  try {
                    await ref.read(exerciseRepositoryProvider).restore(e.id);
                    if (context.mounted) {
                      showMessage(context, S.exerciseRestored(e.name));
                    }
                  } on Object catch (error) {
                    if (context.mounted) showError(context, error);
                  }
                },
                child: const Text(S.restore),
              ),
            );
          },
        ),
      },
    );
  }
}
