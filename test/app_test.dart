import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import 'helpers/pump_app.dart';
import 'helpers/test_db.dart';

Finder _appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

void main() {
  testWidgets('starts on the training tab with four destinations', (
    tester,
  ) async {
    final db = await pumpApp(tester);

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    for (final label in [S.tabTraining, S.tabHistory, S.tabStats, S.tabBody]) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(_appBarTitle(S.tabTraining), findsOneWidget);
    expect(find.text(S.freeEmpty), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('switches tabs via the navigation bar', (tester) async {
    final db = await pumpApp(tester);

    final tabs = {
      S.tabHistory: S.historyEmpty,
      S.tabStats: S.statsNoData,
      S.tabBody: S.bodyFirstHint,
      S.tabTraining: S.freeEmpty,
    };
    for (final MapEntry(key: label, value: empty) in tabs.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(_appBarTitle(label), findsOneWidget);
      expect(find.text(empty), findsOneWidget);
    }
    await disposeApp(tester, db);
  });

  testWidgets('gear opens settings above the shell and back returns', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(S.tabStats),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(S.openSettings));
    await tester.pumpAndSettle();

    expect(_appBarTitle(S.settings), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // pageBack() looks for the English tooltip "Back"; the app is German.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(_appBarTitle(S.tabStats), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('uses German locale and the bundled UI font', (tester) async {
    final db = await pumpApp(tester);
    final context = tester.element(find.byType(NavigationBar));
    expect(Localizations.localeOf(context), const Locale('de', 'DE'));
    expect(Theme.of(context).textTheme.bodyMedium?.fontFamily, 'Barlow');
    await disposeApp(tester, db);
  });

  testWidgets('every gear button is a 48 dp touch target', (tester) async {
    final db = await pumpApp(tester);
    final size = tester.getSize(find.byTooltip(S.openSettings));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await disposeApp(tester, db);
  });

  testWidgets('theme follows the stored theme preference', (tester) async {
    final db = newTestDatabase();
    await SettingsRepository(db)
        .update((s) => s.copyWith(themeMode: ThemePreference.dark));
    await pumpApp(tester, db: db);
    final context = tester.element(find.byType(NavigationBar));
    expect(Theme.of(context).brightness, Brightness.dark);

    await SettingsRepository(db)
        .update((s) => s.copyWith(themeMode: ThemePreference.light));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.light,
    );
    await disposeApp(tester, db);
  });
}
