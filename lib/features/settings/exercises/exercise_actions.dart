import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings_de.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/exercise_repository.dart';
import '../../../domain/models/models.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/snackbars.dart';

/// Asks and then deletes the exercise, or archives it if it has training
/// history (SPEC §5). Returns `true` if it was removed.
Future<bool> removeExerciseWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  Exercise exercise,
) async {
  final repo = ref.read(exerciseRepositoryProvider);
  final hasHistory = await repo.hasHistory(exercise.id);
  final planCount = await repo.planCount(exercise.id);
  if (!context.mounted) return false;
  final confirmed = await showConfirmDialog(
    context,
    title: hasHistory
        ? S.archiveExerciseTitle(exercise.name)
        : S.deleteExerciseTitle(exercise.name),
    body:
        (hasHistory ? S.archiveExerciseBody : S.deleteExerciseBody) +
        S.removedFromPlans(planCount),
    confirmLabel: hasHistory ? S.archive : S.delete,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return false;
  try {
    final result = await repo.deleteOrArchive(exercise.id);
    if (!context.mounted) return true;
    showMessage(
      context,
      result == ExerciseRemoval.archived
          ? S.exerciseArchived(exercise.name)
          : S.exerciseDeleted(exercise.name),
    );
    return true;
  } on Object catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}
