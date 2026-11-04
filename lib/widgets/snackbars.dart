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
  // SnackBar measures the action without the text scale; with large system
  // fonts the action would squeeze the message (words broken mid-word), so
  // it goes to its own line then (M10).
  final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        actionOverflowThreshold: largeText ? 0 : null,
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
