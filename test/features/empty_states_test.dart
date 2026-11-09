import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import '../helpers/pump_app.dart';
import '../helpers/seed.dart';
import '../helpers/test_db.dart';

/// M10: every screen explains itself when there is nothing to show yet.
void main() {
  late AppDatabase db;
  late Repos r;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db);
    await settle(tester);
  }

  testWidgets('tabs of a fresh install', (tester) async {
    await open(tester);
    expect(find.text(S.noPlansYet), findsOneWidget);
    await tester.tap(find.text(S.tabHistory));
    await settle(tester);
    expect(find.text(S.historyEmpty), findsOneWidget);
    await tester.tap(find.text(S.tabStats).last);
    await settle(tester);
    expect(find.text(S.statsNoData), findsOneWidget);
    await tester.tap(find.text(S.tabBody));
    await settle(tester);
    expect(find.text(S.bodyFirstHint), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('empty plan, empty picker, empty session', (tester) async {
    await dbWork(tester, () async {
      final plan = await r.plans.create('Leer');
      await SettingsRepository(db)
          .update((s) => s.copyWith(lastSelectedPlanId: plan));
    });
    await open(tester);
    expect(find.text(S.planEmpty), findsOneWidget);
    await tester.tap(find.text(S.addExercise));
    await settle(tester);
    expect(find.text(S.pickerEmpty), findsOneWidget);
    await tester.tapAt(const Offset(200, 60));
    await settle(tester);
    await tester.tap(find.text(S.startTraining));
    await settle(tester);
    expect(find.text(S.sessionEmpty), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('settings lists', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip(S.openSettings));
    await settle(tester);
    await tester.tap(find.text(S.settingsExercises));
    await settle(tester);
    expect(find.text(S.exercisesEmpty), findsOneWidget);
    await tester.tap(find.byTooltip(S.openArchive));
    await settle(tester);
    expect(find.text(S.archiveEmpty), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.text(S.settingsPlans));
    await settle(tester);
    expect(find.text(S.plansEmpty), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('history detail without exercises', (tester) async {
    await dbWork(tester, () async {
      final e = await addExercise(r, 'Bank');
      final id = await r.sessions.start(
        exercises: [SessionExerciseDraft(exerciseId: e, targetSets: 1)],
      );
      final d = await r.sessions.getDetails(id);
      await r.sessions.saveSet(
        d.single.sessionExercise.id,
        const SetValues(weightKg: 50, reps: 5),
      );
      await r.sessions.finishSession(id);
      await r.sessions.removeSessionExercise(d.single.sessionExercise.id);
    });
    await open(tester);
    await tester.tap(find.text(S.tabHistory));
    await settle(tester);
    await tester.tap(find.textContaining(S.freeTrainingTitle));
    await settle(tester);
    expect(find.text(S.sessionDetailEmpty), findsOneWidget);
    await disposeApp(tester, db);
  });
}
