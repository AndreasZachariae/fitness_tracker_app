import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/app.dart';
import 'package:gymlog/core/l10n/strings_de.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: GymLogApp()));
  await tester.pumpAndSettle();
}

Finder _appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

void main() {
  testWidgets('starts on the training tab with four destinations', (
    tester,
  ) async {
    await _pumpApp(tester);

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
    expect(find.text(S.trainingEmpty), findsOneWidget);
  });

  testWidgets('switches tabs via the navigation bar', (tester) async {
    await _pumpApp(tester);

    final tabs = {
      S.tabHistory: S.historyEmpty,
      S.tabStats: S.statsEmpty,
      S.tabBody: S.bodyEmpty,
      S.tabTraining: S.trainingEmpty,
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
  });

  testWidgets('gear opens settings above the shell and back returns', (
    tester,
  ) async {
    await _pumpApp(tester);
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
  });

  testWidgets('uses German locale and the bundled UI font', (tester) async {
    await _pumpApp(tester);
    final context = tester.element(find.byType(NavigationBar));
    expect(Localizations.localeOf(context), const Locale('de', 'DE'));
    expect(Theme.of(context).textTheme.bodyMedium?.fontFamily, 'Barlow');
  });

  testWidgets('every gear button is a 48 dp touch target', (tester) async {
    await _pumpApp(tester);
    final size = tester.getSize(find.byTooltip(S.openSettings));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
