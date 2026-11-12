import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../data/io/data_transfer_service.dart';
import '../../../data/providers.dart';
import '../../../domain/serialization/backup.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/snackbars.dart';

enum _Target { downloads, share, saveAs }

Future<_Target?> _chooseTarget(
  BuildContext context,
  String title, {
  bool downloads = true,
}) => showModalBottomSheet<_Target>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (downloads)
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text(S.saveToDownloadsAction),
            subtitle: const Text(S.downloadsFolder),
            onTap: () => Navigator.pop(context, _Target.downloads),
          ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: const Text(S.shareAction),
          onTap: () => Navigator.pop(context, _Target.share),
        ),
        ListTile(
          leading: const Icon(Icons.save_alt),
          title: const Text(S.saveAsAction),
          onTap: () => Navigator.pop(context, _Target.saveAs),
        ),
      ],
    ),
  ),
);

/// Hands [file] over; `true` if delivered. Saved into Download/GymLog
/// (1.6.1), a message says where it lies.
Future<bool> _deliver(
  BuildContext context,
  WidgetRef ref,
  _Target target,
  ExportFile file,
) async {
  final files = ref.read(fileGatewayProvider);
  switch (target) {
    case _Target.downloads:
      final where = await files.saveToDownloads(
        file.bytes,
        file.name,
        file.mimeType,
      );
      if (context.mounted) showMessage(context, S.savedIn(where));
      return true;
    case _Target.share:
      return files.share(file.bytes, file.name, file.mimeType);
    case _Target.saveAs:
      return files.saveAs(file.bytes, file.name, file.mimeType);
  }
}

Future<void> _backup(
  BuildContext context,
  WidgetRef ref,
  _Target target,
) async {
  final service = ref.read(dataTransferProvider);
  try {
    final file = await service.createBackup();
    if (!context.mounted) return;
    if (await _deliver(context, ref, target, file)) {
      await service.markBackedUp();
    }
  } on Object {
    if (context.mounted) showMessage(context, S.exportFailed);
  }
}

/// "Backup erstellen" (1.6.1): straight into Download/GymLog, no dialog;
/// on success `lastBackupAt` is set.
Future<void> createBackupFlow(BuildContext context, WidgetRef ref) =>
    _backup(context, ref, _Target.downloads);

/// "Backup teilen oder anderswo speichern": share or "Speichern unter …".
Future<void> createBackupElsewhereFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  final target = await _chooseTarget(
    context,
    S.backupElsewhere,
    downloads: false,
  );
  if (target == null || !context.mounted) return;
  await _backup(context, ref, target);
}

/// "CSV exportieren" (does not count as a backup).
Future<void> exportCsvFlow(BuildContext context, WidgetRef ref) async {
  final target = await _chooseTarget(context, S.exportCsv);
  if (target == null) return;
  try {
    final file = await ref.read(dataTransferProvider).createCsvExport();
    if (!context.mounted) return;
    await _deliver(context, ref, target, file);
  } on Object {
    if (context.mounted) showMessage(context, S.exportFailed);
  }
}

String _importError(Object e) => switch (e) {
  BackupFormatException(error: BackupError.notJson) ||
  UnreadableFileException() => S.importNotJson,
  BackupFormatException(error: BackupError.wrongFormat) => S.importWrongFormat,
  BackupFormatException(error: BackupError.newerVersion) =>
    S.importNewerVersion,
  _ => S.importInvalid,
};

/// "Backup wiederherstellen" (SPEC §8.3): pick, validate, preview,
/// confirm, safety copy, import in one transaction.
Future<void> restoreBackupFlow(BuildContext context, WidgetRef ref) async {
  final service = ref.read(dataTransferProvider);
  if (await ref.read(sessionRepositoryProvider).getActive() != null) {
    if (context.mounted) showMessage(context, S.restoreBlocked);
    return;
  }
  final bytes = await ref.read(fileGatewayProvider).pickFile();
  if (bytes == null || !context.mounted) return;

  final BackupData backup;
  try {
    backup = service.readBackup(bytes);
  } on Object catch (e) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.importErrorTitle),
        content: Text(_importError(e)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(S.ok),
          ),
        ],
      ),
    );
    return;
  }

  final p = service.preview(backup);
  final period = p.first == null
      ? ''
      : S.restorePeriod(formatDateLong(p.first!), formatDateLong(p.last!));
  if (!context.mounted) return;
  final ok = await showConfirmDialog(
    context,
    title: S.restoreTitle,
    body:
        '${S.restorePreview(p.trainings, period, p.bodyWeights)}\n\n'
        '${S.restoreWarning}',
    confirmLabel: S.restoreConfirm,
    destructive: true,
  );
  if (!ok) return;
  try {
    await service.restore(backup);
  } on ImportBlockedException {
    if (context.mounted) showMessage(context, S.restoreBlocked);
  } on Object {
    if (context.mounted) showMessage(context, S.restoreFailed);
  }
}
