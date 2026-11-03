import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/core/theme/app_theme.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/providers.dart';
import 'package:gymlog/data/repositories/maintenance_repository.dart';
import 'package:gymlog/features/settings/settings_page.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDatabase());

  Future<void> pumpSettings(WidgetTester tester, {bool dev = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(newTestClock()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: SettingsPage(showDevTools: dev),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToDev(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.text(S.devDeleteAll),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  }

  Future<DataCounts> counts(WidgetTester tester) async =>
      (await tester.runAsync(() => MaintenanceRepository(db).counts()))!;

  testWidgets('release app shows no dev tools', (tester) async {
    await pumpSettings(tester, dev: false);
    expect(find.text(S.devDemoData), findsNothing);
    expect(find.text(S.devDeleteAll), findsNothing);
    expect(find.text(S.settingsExercises), findsOneWidget);
    expect(find.text(S.settingsPlans), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('demo data: cancel changes nothing, confirm fills the database', (
    tester,
  ) async {
    await pumpSettings(tester);
    await scrollToDev(tester);
    expect(find.text(S.devSection), findsOneWidget);

    await tester.tap(find.text(S.devDemoData));
    await tester.pumpAndSettle();
    expect(find.text(S.devDemoDataConfirmTitle), findsOneWidget);
    await tester.tap(find.text(S.cancel));
    await tester.pumpAndSettle();
    expect((await counts(tester)).isEmpty, isTrue);

    await tester.tap(find.text(S.devDemoData));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text(S.devDemoDataConfirm));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    final c = await counts(tester);
    expect(c.sessions, greaterThan(0));
    expect(find.textContaining('Demo-Daten erzeugt:'), findsOneWidget);
    expect(find.textContaining('${c.sessions} Trainings'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('delete all data asks first, then deletes', (tester) async {
    await tester.runAsync(
      () => db.customStatement(
        'INSERT INTO plans (name, position, created_at) '
        "VALUES ('Push', 0, '2026-11-01T10:00:00.000Z')",
      ),
    );
    await pumpSettings(tester);
    await scrollToDev(tester);

    await tester.tap(find.text(S.devDeleteAll));
    await tester.pumpAndSettle();
    expect(find.text(S.devDeleteAllConfirmBody), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text(S.devDeleteAllConfirm));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect((await counts(tester)).plans, 0);
    expect(find.text(S.devDeleteAllDone), findsOneWidget);
    await dispose(tester);
  });
}
