import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

import '../../core/clock.dart';
import '../../domain/models/models.dart';
import '../../domain/serialization/backup.dart';
import '../../domain/serialization/csv_export.dart';
import '../db/database.dart';
import '../db/storage_time.dart';
import '../repositories/maintenance_repository.dart';
import '../repositories/settings_repository.dart';
import 'file_gateway.dart';

/// A file ready to be shared or saved.
typedef ExportFile = ({String name, Uint8List bytes, String mimeType});

/// An import is not possible while a session runs (SPEC §8.3).
final class ImportBlockedException implements Exception {
  const ImportBlockedException();
}

/// The file could not be read as UTF-8 text.
final class UnreadableFileException implements Exception {
  const UnreadableFileException();
}

/// CSV export, JSON backup and import (SPEC §8).
class DataTransferService {
  DataTransferService({
    required this.db,
    required this.clock,
    required this.files,
    required this.appVersion,
  }) : _maintenance = MaintenanceRepository(db),
       _settings = SettingsRepository(db);

  /// Number of safety copies kept before an import.
  static const keepSafetyCopies = 3;
  static const safetyFolder = 'safety-copies';

  final AppDatabase db;
  final Clock clock;
  final FileGateway files;

  /// "1.0.0+12" for the backup header.
  final Future<String> Function() appVersion;

  final MaintenanceRepository _maintenance;
  final SettingsRepository _settings;

  static String _stamp(DateTime t, String pattern) =>
      DateFormat(pattern).format(t.toLocal());

  /// `gymlog-export-YYYY-MM-DD.zip` with the four CSV files.
  Future<ExportFile> createCsvExport() async {
    final csv = buildCsvExport(await _maintenance.loadDataset());
    final archive = Archive();
    for (final MapEntry(key: name, value: content) in csv.entries) {
      archive.add(ArchiveFile.bytes(name, utf8.encode(content)));
    }
    return (
      name: 'gymlog-export-${_stamp(clock.now(), 'yyyy-MM-dd')}.zip',
      bytes: ZipEncoder().encodeBytes(archive),
      mimeType: 'application/zip',
    );
  }

  /// `gymlog-backup-YYYY-MM-DD-HHmm.json` with all data.
  Future<ExportFile> createBackup() async {
    final now = clock.now();
    final json = encodeBackup(
      BackupData(
        dataset: await _maintenance.loadDataset(),
        settings: await _settings.get(),
        schemaVersion: db.schemaVersion,
        appVersion: await appVersion(),
        exportedAt: now,
      ),
    );
    return (
      name: 'gymlog-backup-${_stamp(now, 'yyyy-MM-dd-HHmm')}.json',
      bytes: Uint8List.fromList(utf8.encode(json)),
      mimeType: 'application/json',
    );
  }

  /// After a backup was shared or saved (CSV exports do not count).
  Future<void> markBackedUp() => _settings.update(
    (s) => s.copyWith(lastBackupAt: storageTime(clock.now())),
  );

  /// Parses and validates a picked file (throws [BackupFormatException]).
  BackupData readBackup(Uint8List bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const UnreadableFileException();
    }
    return decodeBackup(text);
  }

  /// Replaces all data by [backup] after writing a safety copy of the
  /// current state. Everything happens in one transaction.
  Future<void> restore(BackupData backup) async {
    if (await db.sessionsDao.getActive() != null) {
      throw const ImportBlockedException();
    }
    await _writeSafetyCopy();
    await _maintenance.replaceAll(backup.dataset, settings: backup.settings);
  }

  Future<void> _writeSafetyCopy() async {
    final current = await createBackup();
    final docs = await files.documentsDirectory();
    final dir = Directory('${docs.path}/$safetyFolder');
    await dir.create(recursive: true);
    final name = current.name.replaceFirst(
      'gymlog-backup-',
      'gymlog-safety-${_stamp(clock.now(), 'yyyyMMdd-HHmmss')}-',
    );
    await File('${dir.path}/$name').writeAsBytes(current.bytes, flush: true);
    final copies =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in copies.skip(keepSafetyCopies)) {
      await old.delete();
    }
  }

  /// Preview for the confirmation dialog.
  ImportPreview preview(BackupData backup) => previewOf(backup.dataset);

  /// Current data, for "identical after import" checks.
  Future<(Dataset, AppSettings)> snapshot() async =>
      (await _maintenance.loadDataset(), await _settings.get());
}
