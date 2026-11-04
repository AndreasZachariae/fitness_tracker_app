import 'package:flutter/material.dart';

import '../core/l10n/strings_de.dart';

/// Small "ⓘ" button that explains a value in a dialog.
class InfoButton extends StatelessWidget {
  const InfoButton({required this.title, required this.text, super.key});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      tooltip: '${S.explain}: $title',
      onPressed: () => showInfoDialog(context, title: title, text: text),
    );
  }
}

Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String text,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: SingleChildScrollView(child: Text(text)),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(S.ok),
      ),
    ],
  ),
);
