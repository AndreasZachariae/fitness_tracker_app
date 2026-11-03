import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../widgets/confirm_dialog.dart';

/// "Demo-Daten erzeugen" and "Alle Daten löschen" (DEV app only).
class DevToolsSection extends ConsumerStatefulWidget {
  const DevToolsSection({super.key});

  @override
  ConsumerState<DevToolsSection> createState() => _DevToolsSectionState();
}

class _DevToolsSectionState extends ConsumerState<DevToolsSection> {
  bool _busy = false;

  Future<void> _run({
    required String title,
    required String body,
    required String confirmLabel,
    required bool destructive,
    required Future<String> Function() action,
    required String failure,
  }) async {
    final confirmed = await showConfirmDialog(
      context,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      destructive: destructive,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    String message;
    try {
      message = await action();
    } on Object {
      message = failure;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _generateDemoData() => _run(
    title: S.devDemoDataConfirmTitle,
    body: S.devDemoDataConfirmBody,
    confirmLabel: S.devDemoDataConfirm,
    destructive: false,
    failure: S.devDemoDataFailed,
    action: () async {
      final counts = await ref.read(devToolsProvider).generateDemoData();
      final number = NumberFormat.decimalPattern(appLocale);
      return S.devDemoDataDone(
        number.format(counts.sessions),
        number.format(counts.sets),
        number.format(counts.bodyWeights),
      );
    },
  );

  Future<void> _deleteAll() => _run(
    title: S.devDeleteAllConfirmTitle,
    body: S.devDeleteAllConfirmBody,
    confirmLabel: S.devDeleteAllConfirm,
    destructive: true,
    failure: S.devDeleteAllFailed,
    action: () async {
      await ref.read(devToolsProvider).deleteAllData();
      return S.devDeleteAllDone;
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            S.devSection,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.auto_awesome_outlined),
          title: const Text(S.devDemoData),
          subtitle: const Text(S.devDemoDataSubtitle),
          trailing: _busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : null,
          onTap: _generateDemoData,
        ),
        ListTile(
          enabled: !_busy,
          leading: Icon(Icons.delete_forever_outlined, color: error),
          title: Text(S.devDeleteAll, style: TextStyle(color: error)),
          subtitle: const Text(S.devDeleteAllSubtitle),
          onTap: _deleteAll,
        ),
      ],
    );
  }
}
