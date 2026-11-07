import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// 1.1.0: lbs plates and levels in the running training.
void main() {
  late AppDatabase db;
  late Repos r;
  late FixedClock clock;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
    clock = newTestClock();
  });

  /// [draft] trained 3 × 10 with [weight] three days ago, now running with
  /// target 3 × 10.
  Future<void> seed(WidgetTester tester, ExerciseDraft draft, double weight) =>
      dbWork(tester, () async {
        final id = await r.exercises.create(draft);
        final old = SessionRepository(
          db,
          FixedClock(testNow.subtract(const Duration(days: 3))),
        );
        final s = await old.start(
          exercises: [SessionExerciseDraft(exerciseId: id, targetSets: 3)],
        );
        final se = (await old.getDetails(s)).single.sessionExercise;
        for (var i = 0; i < 3; i++) {
          await old.addSet(se.id, weightKg: weight, reps: 10);
        }
        await old.finish(s);
        await SessionRepository(db, clock).start(
          exercises: [
            SessionExerciseDraft(exerciseId: id, targetSets: 3, targetReps: 10),
          ],
        );
      });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db, clock: clock);
    await settle(tester);
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await settle(tester);
  }

  Future<double?> lastSavedWeight(WidgetTester tester) async {
    final sets = await dbWork(tester, () => db.select(db.setEntries).get());
    return sets.last.weightKg;
  }

  testWidgets('standard 15 lbs: + and − jump between the printed plates', (
    tester,
  ) async {
    await seed(
      tester,
      const ExerciseDraft(
        name: 'Latzug',
        type: ExerciseType.weightReps,
        stepMode: StepMode.standard,
      ),
      45,
    );
    await open(tester);
    expect(find.text('45 kg'), findsOneWidget);
    // Suggestion: the next plate, 7 kg heavier.
    expect(find.text(S.suggestion('+7 kg')), findsOneWidget);

    await tapVisible(tester, find.byTooltip('${S.weight}: ${S.increase}'));
    expect(find.text('52 kg'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('${S.weight}: ${S.increase}'));
    expect(find.text('59 kg'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('${S.weight}: ${S.decrease}'));
    await tapVisible(tester, find.byTooltip('${S.weight}: ${S.decrease}'));
    await tapVisible(tester, find.byTooltip('${S.weight}: ${S.decrease}'));
    expect(find.text('39 kg'), findsOneWidget);
    await tapVisible(tester, find.text(S.saveSet));
    expect(await lastSavedWeight(tester), 39, reason: 'stored in kg');
    await disposeApp(tester, db);
  });

  testWidgets('levels with 4.5 kg: level shown, kg alongside and stored', (
    tester,
  ) async {
    await seed(
      tester,
      const ExerciseDraft(
        name: 'Bizepscurls am Kabel',
        type: ExerciseType.weightReps,
        stepMode: StepMode.levels,
        levelKg: 4.5,
      ),
      45,
    );
    await open(tester);
    expect(find.text('${S.level} · 45 kg'), findsOneWidget);
    expect(find.text('10'), findsWidgets);
    expect(find.text(S.suggestion(S.plusOneLevel)), findsOneWidget);
    expect(
      find.textContaining('${S.level} 10 × 10, 10 × 10, 10 × 10'),
      findsOneWidget,
      reason: 'last time in levels',
    );

    await tapVisible(
      tester,
      find.byTooltip('${S.level} · 45 kg: ${S.increase}'),
    );
    expect(find.text('${S.level} · 49,5 kg'), findsOneWidget);
    await tapVisible(tester, find.text(S.saveSet));
    expect(await lastSavedWeight(tester), 49.5);
    expect(find.text('${S.level} 11 (49,5 kg) × 10'), findsOneWidget);

    // Typing a level instead of kg.
    await tapVisible(tester, find.text('11'));
    expect(find.text(S.enterLevel), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text(S.ok));
    await settle(tester);
    expect(find.text('${S.level} · 54 kg'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('levels without kg: only the level number', (tester) async {
    await seed(
      tester,
      const ExerciseDraft(
        name: 'Seil ohne kg',
        type: ExerciseType.weightReps,
        stepMode: StepMode.levels,
      ),
      7,
    );
    await open(tester);
    expect(find.text(S.level), findsOneWidget, reason: 'label without kg');
    await tapVisible(tester, find.byTooltip('${S.level}: ${S.increase}'));
    expect(find.text('8'), findsWidgets);
    await tapVisible(tester, find.text(S.saveSet));
    expect(await lastSavedWeight(tester), 8, reason: 'the level number');
    expect(find.text('${S.level} 8 × 10'), findsOneWidget);
    await disposeApp(tester, db);
  });
}
