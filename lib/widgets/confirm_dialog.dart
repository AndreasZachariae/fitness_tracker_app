import 'package:flutter/material.dart';

import '../core/l10n/strings_de.dart';

/// Asks for confirmation; returns `true` only if [confirmLabel] was tapped.
///
/// [destructive] colors the confirm button red (SPEC §9).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? body,
  String cancelLabel = S.cancel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            style: destructive
                ? TextButton.styleFrom(foregroundColor: scheme.error)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
