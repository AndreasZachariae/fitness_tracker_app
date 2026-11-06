import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/demo/demo_data.dart';
import 'package:gymlog/data/repositories/maintenance_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/serialization/backup.dart';

import '../../helpers/fake_files.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// Settings §6.7 and data export/backup/import §8.
void main() {
  late AppDatabase db;
  late Directory tmp;
  late FakeFileGateway files;

  setUp(() {
    db = newTestDatabase();
    tmp = Directory.systemTemp.createTempSync('gymlog-ui');
    files = FakeFileGateway(tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db, files: files);
    await tester.tap(find.byTooltip(S.openSettings));
    await settle(tester);
  }

  /// Lets real file I/O (safety copy) finish between frames.
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.dragUntilVisible(
      find.text(text),
      find.byType(ListView),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls the section "Daten" to the top: reminder card and all tiles
  /// are on screen.
  Future<void> showData(WidgetTester tester) async {
    await scrollTo(tester, S.sectionData);
    final y = tester.getTopLeft(find.text(S.sectionData)).dy;
    await tester.drag(find.byType(ListView), Offset(0, 120 - y));
    await tester.pumpAndSettle();
  }

  Future<AppSettings> settings(WidgetTester tester) =>
      dbWork(tester, () => SettingsRepository(db).get());

  testWidgets('training settings and theme are saved', (tester) async {
    await openSettings(tester);
    await tester.tap(find.byTooltip('${S.settingDefaultSets}: ${S.increase}'));
    await tester.tap(find.byTooltip('${S.settingDefaultRest}: ${S.decrease}'));
    await settle(tester);
    await tester.tap(find.text(S.settingVibration));
    await tester.tap(find.text(S.settingAutoActivate));
    await settle(tester);
    var s = await settings(tester);
    expect(
      (s.defaultSets, s.defaultRestSec, s.vibrationEnabled, s.autoActivateNext),
      (4, 75, false, true),
    );

    await scrollTo(tester, S.themeDark);
    await tester.tap(find.text(S.themeDark));
    await settle(tester);
    s = await settings(tester);
    expect(s.themeMode, ThemePreference.dark);
    expect(
      Theme.of(tester.element(find.text(S.themeDark))).brightness,
      Brightness.dark,
    );
    await disposeApp(tester, db);
  });

  testWidgets('about: version, build, schema version', (tester) async {
    await openSettings(tester);
    await scrollTo(tester, S.schemaVersion);
    expect(find.text('0.9.0'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('${AppDatabase.currentSchemaVersion}'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('backup: share sets "Letztes Backup", dismiss does not', (
    tester,
  ) async {
    await dbWork(
      tester,
      () =>
          MaintenanceRepository(db).replaceAll(generateDemoData(now: testNow)),
    );
    await openSettings(tester);
    await showData(tester);
    // Tile subtitle and the reminder card (1.0.1).
    expect(find.text(S.noBackupYet), findsNWidgets(2));

    files.dismissShare = true;
    await tester.tap(find.widgetWithText(ListTile, S.createBackup));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.shareAction));
    await settle(tester);
    expect((await settings(tester)).lastBackupAt, isNull);

    files.dismissShare = false;
    await tester.tap(find.widgetWithText(ListTile, S.createBackup));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.shareAction));
    await settle(tester);
    expect(files.shared.single.$1, startsWith('gymlog-backup-'));
    expect((await settings(tester)).lastBackupAt, testNow);
    expect(find.text(S.lastBackup('3.11.2026, 18:20')), findsOneWidget);
    expect(find.text(S.noBackupYet), findsNothing, reason: 'card gone');
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'no confirmation (1.0.1)',
    );
    expect(
      () => decodeBackup(utf8.decode(files.shared.single.$2)),
      returnsNormally,
    );
    await disposeApp(tester, db);
  });

  testWidgets('"Speichern unter …" works too; CSV is not a backup', (
    tester,
  ) async {
    await openSettings(tester);
    await scrollTo(tester, S.exportCsv);
    await tester.tap(find.text(S.exportCsv));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.saveAsAction));
    await settle(tester);
    expect(files.saved.single.$1, startsWith('gymlog-export-'));
    final zip = ZipDecoder().decodeBytes(files.saved.single.$2);
    expect(zip.files, hasLength(4));
    expect((await settings(tester)).lastBackupAt, isNull);
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'no confirmation (1.0.1)',
    );
    await disposeApp(tester, db);
  });

  testWidgets('restore: preview, confirm, data replaced', (tester) async {
    final demo = generateDemoData(now: testNow);
    files.nextPick = Uint8List.fromList(
      utf8.encode(
        encodeBackup(
          BackupData(
            dataset: demo,
            settings: AppSettings.defaults,
            schemaVersion: 1,
            appVersion: '0.9.0+9',
            exportedAt: testNow,
          ),
        ),
      ),
    );
    await dbWork(tester, () => addExercise(Repos(db), 'Wird ersetzt'));
    await openSettings(tester);
    await scrollTo(tester, S.restoreBackup);
    await tester.tap(find.text(S.restoreBackup));
    await settle(tester);

    expect(find.text(S.restoreTitle), findsOneWidget);
    expect(
      find.textContaining('${demo.sessions.length} Trainings vom '),
      findsOneWidget,
    );
    expect(find.textContaining(S.restoreWarning), findsOneWidget);
    await tester.tap(find.text(S.restoreConfirm));
    await settleIo(tester);

    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'no confirmation (1.0.1)',
    );
    final counts = await dbWork(
      tester,
      () => MaintenanceRepository(db).counts(),
    );
    expect(counts.sessions, demo.sessions.length);
    final names = (await dbWork(
      tester,
      () => Repos(db).exercises.watchActive().first,
    )).map((e) => e.name);
    expect(names, isNot(contains('Wird ersetzt')));
    expect(
      Directory('${tmp.path}/safety-copies').listSync(),
      hasLength(1),
      reason: 'safety copy of the previous state',
    );
    await disposeApp(tester, db);
  });

  testWidgets('restore: invalid file explains and changes nothing', (
    tester,
  ) async {
    files.nextPick = Uint8List.fromList(utf8.encode('{"format":"other"}'));
    await dbWork(tester, () => addExercise(Repos(db), 'Bleibt'));
    await openSettings(tester);
    await scrollTo(tester, S.restoreBackup);
    await tester.tap(find.text(S.restoreBackup));
    await settle(tester);
    expect(find.text(S.importErrorTitle), findsOneWidget);
    expect(find.text(S.importWrongFormat), findsOneWidget);
    await tester.tap(find.text(S.ok));
    await tester.pumpAndSettle();
    expect(
      (await dbWork(
        tester,
        () => Repos(db).exercises.watchActive().first,
      )).single.name,
      'Bleibt',
    );
    await disposeApp(tester, db);
  });

  testWidgets('restore is locked during a session', (tester) async {
    await dbWork(tester, () => Repos(db).sessions.start(exercises: const []));
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db, files: files);
    await settle(tester);
    // The session screen has no gear; the other tabs do.
    await tester.tap(find.text(S.tabHistory));
    await settle(tester);
    await tester.tap(find.byTooltip(S.openSettings));
    await settle(tester);
    await scrollTo(tester, S.restoreBackup);
    expect(find.text(S.restoreBlocked), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text(S.restoreBackup),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.enabled, isFalse);
    await disposeApp(tester, db);
  });

  /// A training of today with one set; the last backup was 40 days ago.
  Future<void> seedTraining(
    WidgetTester tester, {
    int? reminderDays,
    bool finished = true,
  }) => dbWork(tester, () async {
    await SettingsRepository(db).update(
      (s) => s.copyWith(
        lastBackupAt: testNow.subtract(const Duration(days: 40)),
        backupReminderDays: reminderDays ?? s.backupReminderDays,
      ),
    );
    final r = Repos(db);
    final e = await addExercise(r, 'Bank');
    final id = await r.sessions.start(
      exercises: [SessionExerciseDraft(exerciseId: e, targetSets: 1)],
    );
    final se = (await r.sessions.getDetails(id)).single.sessionExercise;
    await r.sessions.saveSet(se.id, const SetValues(weightKg: 50, reps: 5));
    if (finished) await r.sessions.finishSession(id);
  });

  testWidgets('summary has no backup reminder any more (1.0.1)', (
    tester,
  ) async {
    await seedTraining(tester, finished: false);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db, files: files);
    await settle(tester);
    await tester.tap(find.text(S.finishTraining));
    await settle(tester);
    expect(find.text(S.summaryTitle), findsOneWidget);
    expect(find.text(S.backupAgo(40)), findsNothing);
    await disposeApp(tester, db);
  });

  testWidgets('settings remind of an old backup under "Daten" (1.0.1)', (
    tester,
  ) async {
    await seedTraining(tester);
    await openSettings(tester);
    await showData(tester);
    expect(find.text(S.backupAgo(40)), findsOneWidget, reason: '> 30 days');
    final card = find.ancestor(
      of: find.text(S.backupAgo(40)),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: card, matching: find.text(S.createBackup)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.shareAction));
    await settle(tester);
    expect(files.shared, hasLength(1));
    expect(find.text(S.backupAgo(40)), findsNothing);
    await disposeApp(tester, db);
  });

  testWidgets('no reminder when switched off or recent enough', (tester) async {
    await seedTraining(tester, reminderDays: 0);
    await openSettings(tester);
    await showData(tester);
    expect(find.text(S.backupAgo(40)), findsNothing);
    await dbWork(
      tester,
      () =>
          SettingsRepository(db)
              .update((s) => s.copyWith(backupReminderDays: 60)),
    );
    await settle(tester);
    expect(find.text(S.backupAgo(40)), findsNothing, reason: '40 ≤ 60 days');
    await disposeApp(tester, db);
  });
}
