import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/body_weight_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// Tab "Körper" (SPEC §6.6), incl. the widget test of SPEC §10.
void main() {
  late AppDatabase db;
  late BodyWeightRepository repo;
  final today = LocalDate.fromDateTime(testNow);

  setUp(() {
    db = newTestDatabase();
    repo = BodyWeightRepository(db, newTestClock());
  });

  Future<void> openBody(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db);
    await settle(tester);
    await tester.tap(find.text(S.tabBody).last);
    await settle(tester);
  }

  Future<List<BodyWeightEntry>> entries(WidgetTester tester) =>
      dbWork(tester, () => repo.watchAll().first);

  Finder weightField() => find.widgetWithText(TextField, S.weightKgLabel);

  /// 1.6.1: the entries live on their own page.
  Future<void> openEntries(WidgetTester tester, int count) async {
    final tile = find.byKey(const ValueKey('body-entries'));
    await tester.dragUntilVisible(
      tile,
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text(S.bodyEntriesCount(count)), findsOneWidget);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await settle(tester);
    expect(find.text(S.bodyEntries), findsOneWidget);
  }

  testWidgets('first entry: hint, save for today', (tester) async {
    await openBody(tester);
    expect(find.text(S.bodyFirstHint), findsOneWidget);
    expect(find.text(S.today), findsOneWidget);

    await tester.enterText(weightField(), '81,46');
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await settle(tester);
    final list = await entries(tester);
    expect((list.single.date, list.single.weightKg), (today, 81.5));
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'no confirmation (1.0.1)',
    );
    expect(find.text('81,5 kg'), findsWidgets);
    await disposeApp(tester, db);
  });

  testWidgets('invalid weight shows a hint and saves nothing', (tester) async {
    await openBody(tester);
    await tester.enterText(weightField(), '5');
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await settle(tester);
    expect(find.text(S.errorBodyWeight), findsOneWidget);
    expect(await entries(tester), isEmpty);
    await disposeApp(tester, db);
  });

  testWidgets('same day asks before overwriting (SPEC §10)', (tester) async {
    await dbWork(tester, () => repo.save(today, 80));
    await openBody(tester);
    // Prefilled with the last value.
    expect(find.widgetWithText(TextField, '80,0'), findsOneWidget);

    await tester.enterText(weightField(), '79.8');
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();
    expect(find.text(S.overwriteEntry('3.11.')), findsOneWidget);
    await tester.tap(find.text(S.cancel));
    await settle(tester);
    expect((await entries(tester)).single.weightKg, 80);

    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.overwrite));
    await settle(tester);
    final list = await entries(tester);
    expect(list.single.weightKg, 79.8);
    await disposeApp(tester, db);
  });

  testWidgets('key figures and list', (tester) async {
    await dbWork(tester, () async {
      await repo.save(today.addDays(-40), 83);
      await repo.save(today.addDays(-35), 82);
      await repo.save(today.addDays(-2), 81);
      await repo.save(today, 80);
    });
    await openBody(tester);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('80,5 kg'), findsOneWidget, reason: 'Ø 7 Tage');
    expect(find.text('−2,0 kg'), findsOneWidget, reason: '30 Tage');
    expect(find.text('80,0 / 83,0'), findsOneWidget, reason: '3 M');

    await tester.tap(find.text(S.period4w));
    await tester.pumpAndSettle();
    expect(find.text('80,0 / 81,0'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    // Not on the tab itself any more.
    expect(find.text('So, 1.11.'), findsNothing);

    await openEntries(tester, 4);
    // Newest first.
    expect(
      tester.getTopLeft(find.text('Di, 3.11.')).dy,
      lessThan(tester.getTopLeft(find.text('So, 1.11.')).dy),
    );
    await disposeApp(tester, db);
  });

  testWidgets('swipe deletes with undo; tap edits', (tester) async {
    await dbWork(tester, () async {
      await repo.save(today.addDays(-1), 81);
      await repo.save(today, 80);
    });
    await openBody(tester);
    await openEntries(tester, 2);
    await tester.drag(find.text('Mo, 2.11.'), const Offset(-600, 0));
    await settle(tester);
    expect(await entries(tester), hasLength(1));
    expect(find.text(S.entryDeleted('2.11.')), findsOneWidget);
    // Disappears on its own, no swiping needed (1.0.1).
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.persist, isFalse);
    await tester.tap(find.text(S.undo));
    await settle(tester);
    expect(await entries(tester), hasLength(2));

    await tester.tap(find.text('Di, 3.11.'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '79,9');
    await tester.tap(find.text(S.ok));
    await settle(tester);
    expect((await entries(tester)).first.weightKg, 79.9);
    await disposeApp(tester, db);
  });
}
