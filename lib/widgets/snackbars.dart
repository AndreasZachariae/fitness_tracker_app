import 'package:flutter/material.dart';

import '../core/l10n/error_messages.dart';
import '../core/l10n/strings_de.dart';

/// Shows a short message, replacing the current one.
void showMessage(
  BuildContext context,
  String message, {
  VoidCallback? onUndo,
  Duration duration = const Duration(seconds: 4),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: onUndo == null ? duration : const Duration(seconds: 5),
        action: onUndo == null
            ? null
            : SnackBarAction(label: S.undo, onPressed: onUndo),
      ),
    );
}

/// Shows the German message for a data error.
void showError(BuildContext context, Object error) =>
    showMessage(context, errorMessage(error));
