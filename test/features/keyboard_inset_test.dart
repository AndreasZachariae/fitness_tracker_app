import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import '../helpers/pump_app.dart';
import '../helpers/seed.dart';
import '../helpers/test_db.dart';

/// 1.7.1: an open keyboard takes its height off the page once, not twice.
/// Before, a keyboard-high empty band sat above the keyboard on every page
/// (the shell put the keyboard inset back below its Scaffold).
void main() {
  late AppDatabase db;

  setUp(() => db = newTestDatabase());

  const ratio = 2.75;
  const height = 2340 / ratio;
  const keyboard = 300.0;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db);
    await settle(tester);
  }

  void showKeyboard(WidgetTester tester) {
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * ratio);
  }

  testWidgets('Körper: the list reaches down to the keyboard', (tester) async {
    await open(tester);
    await tester.tap(find.text(S.tabBody).last);
    await settle(tester);
    showKeyboard(tester);
    await tester.pumpAndSettle();
    final list = tester.getRect(find.byType(ListView).first);
    expect(list.bottom, closeTo(height - keyboard, 1));
  });

  testWidgets('training: the exercises reach down to the keyboard', (
    tester,
  ) async {
    await dbWork(tester, () async {
      final r = Repos(db);
      final bench = await addExercise(r, 'Bankdrücken');
      await SessionRepository(db, newTestClock()).start(
        exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 3)],
      );
    });
    await open(tester);
    showKeyboard(tester);
    await tester.pumpAndSettle();
    final list = tester.getRect(find.byType(Scrollable).first);
    expect(list.bottom, closeTo(height - keyboard, 1));
  });
}
