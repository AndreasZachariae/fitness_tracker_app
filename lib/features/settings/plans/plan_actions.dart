import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings_de.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/repository_exceptions.dart';
import '../../../domain/models/models.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/name_dialog.dart';
import '../../../widgets/snackbars.dart';

Future<String?> _saveName(Future<void> Function() action) async {
  try {
    await action();
    return null;
  } on DuplicateNameException {
    return S.errorPlanNameTaken;
  } on InvalidNameException {
    return S.errorNameRequired;
  } on Object {
    return S.errorUnexpected;
  }
}

/// Asks for a name and creates a plan; returns its id.
/// Asks for a name and creates the plan; returns its id. The callers open
/// the plan page afterwards for the training days (1.2.1).
Future<int?> createPlanWithDialog(BuildContext context, WidgetRef ref) async {
  int? id;
  await showNameDialog(
    context,
    title: S.newPlan,
    confirmLabel: S.create,
    onSubmit: (name) => _saveName(
      () async => id = await ref.read(planRepositoryProvider).create(name),
    ),
  );
  return id;
}

Future<void> renamePlanWithDialog(
  BuildContext context,
  WidgetRef ref,
  Plan plan,
) => showNameDialog(
  context,
  title: S.renamePlan,
  confirmLabel: S.save,
  initialValue: plan.name,
  onSubmit: (name) =>
      _saveName(() => ref.read(planRepositoryProvider).rename(plan.id, name)),
);

/// Asks for the name of the copy; returns the new plan id.
Future<int?> duplicatePlanWithDialog(
  BuildContext context,
  WidgetRef ref,
  Plan plan,
) async {
  int? id;
  await showNameDialog(
    context,
    title: S.duplicatePlan,
    confirmLabel: S.duplicate,
    initialValue: S.copyName(plan.name),
    onSubmit: (name) => _saveName(
      () async =>
          id = await ref.read(planRepositoryProvider).duplicate(plan.id, name),
    ),
  );
  return id;
}

/// Asks and deletes the plan; the history keeps its name (SPEC §5).
Future<bool> deletePlanWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  Plan plan,
) async {
  final confirmed = await showConfirmDialog(
    context,
    title: S.deletePlanTitle(plan.name),
    body: S.deletePlanBody,
    confirmLabel: S.delete,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return false;
  try {
    await ref.read(planRepositoryProvider).delete(plan.id);
    return true;
  } on Object catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}
