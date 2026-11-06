import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/seed.dart';

/// 1.0.1: the keyboard of the "+ Plan" dialog squeezed the training page
/// behind it (yellow-black overflow band on the phone).
void main() {
  for (final withPlan in [false, true]) {
    testWidgets('keyboard over "Neuer Plan" (plan exists: $withPlan)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      addTearDown(tester.view.resetViewInsets);
      final db = await pumpApp(tester);
      if (withPlan) {
        await tester.tap(find.text(S.addPlanChip));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Push');
        await tester.tap(find.text(S.create));
        await settle(tester);
      }
      await tester.tap(find.text(S.addPlanChip));
      await tester.pumpAndSettle();
      // The keyboard slides in step by step; up to half the screen.
      for (var bottom = 0.0; bottom <= 1170; bottom += 45) {
        tester.view.viewInsets = FakeViewPadding(bottom: bottom);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'inset $bottom');
      }
      expect(find.text(S.newPlan), findsOneWidget);
      await disposeApp(tester, db);
    });
  }
}
