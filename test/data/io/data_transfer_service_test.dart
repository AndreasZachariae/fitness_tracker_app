import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/demo/demo_data.dart';
import 'package:gymlog/data/io/data_transfer_service.dart';
import 'package:gymlog/data/repositories/maintenance_repository.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/serialization/backup.dart';

import '../../helpers/fake_files.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late Directory tmp;
  late FakeFileGateway files;
  late DataTransferService service;

  setUp(() async {
    db = newTestDatabase();
    clock = newTestClock();
    tmp = Directory.systemTemp.createTempSync('gymlog-test');
    files = FakeFileGateway(tmp);
    service = DataTransferService(
      db: db,
      clock: clock,
      files: files,
      appVersion: () async => '0.9.0+9',
    );
    await MaintenanceRepository(db).replaceAll(generateDemoData(now: testNow));
    await SettingsRepository(db).update(
      (s) => s.copyWith(
        lastSelectedPlanId: 2,
        defaultRestSec: 75,
        themeMode: ThemePreference.dark,
      ),
    );
  });

  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('export → import → identical database content (SPEC §8.3)', () async {
    final before = await service.snapshot();
    final backup = await service.createBackup();
    expect(
      backup.name,
      matches(RegExp(r'^gymlog-backup-\d{4}-\d\d-\d\d-\d{4}\.json$')),
    );

    // Change and delete things, then restore.
    await MaintenanceRepository(db).wipeAll();
    expect((await MaintenanceRepository(db).counts()).isEmpty, isTrue);

    await service.restore(service.readBackup(backup.bytes));
    final after = await service.snapshot();
    final (d1, s1) = before;
    final (d2, s2) = after;
    expect(d2.exercises, d1.exercises);
    expect(d2.plans, d1.plans);
    expect(d2.planExercises, d1.planExercises);
    expect(d2.planGroups, d1.planGroups);
    expect(d2.planGroups, isNotEmpty, reason: 'demo has a superset/rotation');
    expect(d2.sessions, d1.sessions);
    expect(d2.sessionExercises, d1.sessionExercises);
    expect(d2.sessionSupersets, d1.sessionSupersets);
    expect(d2.sessionSupersets, isNotEmpty);
    expect(d2.sets, d1.sets);
    expect(d2.bodyWeights, d1.bodyWeights);
    expect(s2, s1);
  });

  test('backup header carries schema and app version', () async {
    final backup = await service.createBackup();
    final json = jsonDecode(utf8.decode(backup.bytes)) as Map<String, Object?>;
    expect(json['schemaVersion'], AppDatabase.currentSchemaVersion);
    expect(json['appVersion'], '0.9.0+9');
  });

  test('CSV export is a zip with four UTF-8 files', () async {
    final export = await service.createCsvExport();
    expect(
      export.name,
      matches(RegExp(r'^gymlog-export-\d{4}-\d\d-\d\d\.zip$')),
    );
    final archive = ZipDecoder().decodeBytes(export.bytes);
    expect(archive.files.map((f) => f.name).toSet(), {
      'sets.csv',
      'sessions.csv',
      'body_weight.csv',
      'exercises.csv',
    });
    final sets = utf8.decode(archive.findFile('sets.csv')!.content);
    expect(sets, contains('Bankdrücken'));
  });

  test('markBackedUp sets lastBackupAt', () async {
    await service.markBackedUp();
    expect((await SettingsRepository(db).get()).lastBackupAt, testNow);
  });

  test('import writes a safety copy and keeps the last 3', () async {
    final backup = service.readBackup((await service.createBackup()).bytes);
    for (var i = 0; i < 5; i++) {
      clock.advance(const Duration(minutes: 1));
      await service.restore(backup);
    }
    final copies = Directory('${tmp.path}/${DataTransferService.safetyFolder}')
        .listSync()
        .whereType<File>()
        .toList();
    expect(copies, hasLength(3));
    final newest = copies
        .map((f) => f.path)
        .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    // A safety copy is itself a valid backup.
    expect(
      () => decodeBackup(File(newest).readAsStringSync()),
      returnsNormally,
    );
  });

  test('import is blocked while a session runs', () async {
    final backup = service.readBackup((await service.createBackup()).bytes);
    await SessionRepository(db, clock).start(exercises: const []);
    await expectLater(
      service.restore(backup),
      throwsA(isA<ImportBlockedException>()),
    );
  });

  test('a failing import rolls back completely', () async {
    final before = await MaintenanceRepository(db).counts();
    final good = service.readBackup((await service.createBackup()).bytes);
    // Invalid for the database (CHECK target_sets 1–10), valid JSON.
    final broken = BackupData(
      dataset: Dataset(
        exercises: good.dataset.exercises,
        plans: good.dataset.plans,
        planExercises: [
          for (final p in good.dataset.planExercises)
            p.copyWith(targetSets: 99),
        ],
      ),
      settings: good.settings,
      schemaVersion: 1,
      appVersion: 'x',
      exportedAt: testNow,
    );
    await expectLater(service.restore(broken), throwsA(anything));
    final after = await MaintenanceRepository(db).counts();
    expect(
      (after.sessions, after.sets, after.bodyWeights),
      (before.sessions, before.sets, before.bodyWeights),
    );
  });

  test('unreadable files are rejected', () {
    expect(
      () => service.readBackup(Uint8List.fromList([0xff, 0xfe, 0x00])),
      throwsA(isA<UnreadableFileException>()),
    );
  });
}
