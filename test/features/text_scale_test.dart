import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/core/theme/typography.dart';
import 'package:gymlog/data/demo/demo_data.dart';
import 'package:gymlog/data/repositories/maintenance_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';

import '../helpers/pump_app.dart';
import '../helpers/seed.dart';
import '../helpers/test_db.dart';

/// M10: every screen works with large system fonts (Android allows up to
/// 200 %). Any overflow fails the test.
Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File('assets/fonts/$file').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  // The real fonts: the default test font is much wider than Barlow and
  // would report overflows that cannot happen on the phone.
  setUpAll(() async {
    await _loadFont(Fonts.ui, [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        'Barlow-$w.ttf',
    ]);
    await _loadFont(Fonts.numbers, [
      for (final w in ['Medium', 'SemiBold', 'Bold'])
        'BarlowSemiCondensed-$w.ttf',
    ]);
  });

  for (final scale in [1.3, 1.5, 2.0]) {
    testWidgets('all screens at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final db = newTestDatabase();
      await tester.runAsync(() async {
        await MaintenanceRepository(db)
            .replaceAll(generateDemoData(now: testNow));
        await SettingsRepository(db)
            .update((s) => s.copyWith(lastSelectedPlanId: 1));
      });
      await pumpApp(tester, db: db);
      await settle(tester);

      Future<void> scrollThrough(Finder scrollable) async {
        for (var i = 0; i < 8; i++) {
          await tester.drag(scrollable, const Offset(0, -500));
          await tester.pumpAndSettle();
        }
      }

      Future<void> tapShown(Finder f) async {
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await settle(tester);
      }

      Future<void> back() async {
        await tester.tap(find.byType(BackButton).last);
        await settle(tester);
      }

      // Training tab with groups.
      await scrollThrough(find.byType(ReorderableListView).first);
      await tapShown(find.text('Unterkörper'));
      await tapShown(find.text('Kniebeuge')); // plan entry sheet
      await tester.tapAt(const Offset(200, 60));
      await settle(tester);

      // Running session: active card, a set, rest bar, other tabs.
      await tester.tap(find.text(S.startTraining));
      await settle(tester);
      await tester.ensureVisible(find.text(S.saveSet));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.saveSet));
      await settle(tester);
      expect(find.text(S.rest), findsOneWidget);
      await scrollThrough(find.byType(ReorderableListView).first);

      // History list and detail.
      await tester.tap(find.text(S.tabHistory));
      await settle(tester);
      await tester.tap(find.textContaining('·').first);
      await settle(tester);
      await scrollThrough(find.byType(ListView).first);
      await back();

      // Statistics: all three tabs.
      await tester.tap(find.text(S.tabStats).last);
      await settle(tester);
      await scrollThrough(find.byType(ListView).first);
      await tester.tap(find.text(S.statsTabOverall));
      await settle(tester);
      await scrollThrough(find.byType(ListView).last);
      await tester.tap(find.text(S.statsTabRecords));
      await settle(tester);
      await scrollThrough(find.byType(ListView).last);

      // Body.
      await tester.tap(find.text(S.tabBody));
      await settle(tester);
      await scrollThrough(find.byType(Scrollable).first);

      // Settings with exercise form and plan list.
      await tester.tap(find.byTooltip(S.openSettings));
      await settle(tester);
      await scrollThrough(find.byType(ListView).first);
      await tester.drag(find.byType(ListView).first, const Offset(0, 5000));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.settingsExercises));
      await settle(tester);
      await tester.tap(find.text('Bankdrücken'));
      await settle(tester);
      await scrollThrough(find.byType(Scrollable).first);
      await back();
      await back();
      await tester.tap(find.text(S.settingsPlans));
      await settle(tester);
      await back();
      await back();

      // Finish → summary.
      await tester.tap(find.text(S.tabTraining));
      await settle(tester);
      await tester.tap(find.text(S.finishTraining));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, S.finishTraining));
      await settle(tester);
      expect(find.text(S.summaryTitle), findsOneWidget);
      await scrollThrough(find.byType(Scrollable).first);

      await disposeApp(tester, db);
    });
  }
}
