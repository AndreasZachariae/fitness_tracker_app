import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Repos r;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
  });

  Future<void> start(WidgetTester tester) async {
    await pumpApp(tester, db: db);
    await settle(tester);
  }

  Future<AppSettings> settings(WidgetTester tester) =>
      dbWork(tester, () => SettingsRepository(db).get());

  Finder chip(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip));

  bool isSelected(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(chip(label)).selected;

  Future<int> seedPlan(WidgetTester tester) => dbWork(tester, () async {
    final bench = await addExercise(r, 'Bankdrücken');
    final pull = await addExercise(r, 'Klimmzüge', ExerciseType.bodyweight);
    final plank = await addExercise(r, 'Plank', ExerciseType.timed);
    final plan = await r.plans.create('Oberkörper');
    await r.plans.addExercise(plan, bench, targetSets: 3, targetReps: 10);
    await r.plans.addExercise(plan, pull, targetSets: 3, targetReps: 8);
    await r.plans.addExercise(
      plan,
      plank,
      targetSets: 3,
      targetDurationSec: 45,
    );
    await SettingsRepository(db)
        .update((s) => s.copyWith(lastSelectedPlanId: plan));
    return plan;
  });

  Future<void> openPicker(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.text(S.addExercise),
      find.byType(ReorderableListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text(S.addExercise));
    await settle(tester);
  }

  testWidgets('without plans: hint, "Plan anlegen" opens the plan page '
      '(1.2.1, no "Frei")', (tester) async {
    await start(tester);
    expect(find.text(S.noPlansYet), findsOneWidget);
    expect(find.text(S.startTraining), findsNothing);
    expect(find.text('Frei'), findsNothing);

    await tester.tap(find.text(S.createFirstPlan));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Spontan');
    await tester.tap(find.text(S.create));
    await settle(tester);
    expect(find.text(S.planSchedule), findsOneWidget, reason: 'plan page');
    await leavePage(tester);
    expect(isSelected(tester, 'Spontan'), isTrue);
    expect(find.text(S.planEmpty), findsOneWidget);
    expect(find.text(S.startTraining), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('"+ Plan" creates and selects a plan, duplicates are refused', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text(S.addPlanChip));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Push  ');
    await tester.tap(find.text(S.create));
    await settle(tester);
    await leavePage(tester);
    expect(isSelected(tester, 'Push'), isTrue);
    expect(find.text(S.planEmpty), findsOneWidget);
    final plans = await dbWork(tester, r.plans.getPlans);
    expect((await settings(tester)).lastSelectedPlanId, plans.single.id);

    await tester.tap(find.text(S.addPlanChip));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'PUSH');
    await tester.tap(find.text(S.create));
    await settle(tester);
    expect(find.text(S.errorPlanNameTaken), findsOneWidget);
    await tester.tap(find.text(S.cancel));
    await tester.pumpAndSettle();
    await disposeApp(tester, db);
  });

  testWidgets('plan list shows targets and the last performance', (
    tester,
  ) async {
    await seedPlan(tester);
    await dbWork(tester, () async {
      final id = await r.sessions.start(
        exercises: const [SessionExerciseDraft(exerciseId: 1, targetSets: 3)],
      );
      final se = (await r.sessions.watchDetails(id).first).single;
      for (final reps in [10, 10, 8]) {
        await r.sessions.addSet(
          se.sessionExercise.id,
          weightKg: 60,
          reps: reps,
        );
      }
      await r.sessions.finish(id);
    });
    await start(tester);

    expect(isSelected(tester, 'Oberkörper'), isTrue);
    expect(find.text('3 × 10'), findsOneWidget);
    expect(find.text('3 × 8'), findsOneWidget);
    expect(find.text('3 × 45 s'), findsOneWidget);
    expect(find.text('Zuletzt: 60 kg × 10, 10, 8'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('selecting a chip is remembered', (tester) async {
    final first = await seedPlan(tester);
    final second = await dbWork(tester, () => r.plans.create('Beine'));
    await start(tester);
    await tester.tap(find.text('Beine'));
    await settle(tester);
    expect((await settings(tester)).lastSelectedPlanId, second);
    expect(find.text(S.planEmpty), findsOneWidget);
    await tester.tap(find.text('Oberkörper'));
    await settle(tester);
    expect((await settings(tester)).lastSelectedPlanId, first);
    expect(find.text('Bankdrücken'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('plan chips: single choice without checkmark, colored (M9)', (
    tester,
  ) async {
    await seedPlan(tester);
    final second = await dbWork(tester, () => r.plans.create('Beine'));
    await start(tester);
    final chipWidget = tester.widget<ChoiceChip>(chip('Oberkörper'));
    expect(chipWidget.showCheckmark, isFalse);
    expect(chipWidget.selectedColor, isNotNull);
    // The new selection shows at once, before the database round trip.
    await tester.tap(find.text('Beine'));
    await tester.pump();
    expect(isSelected(tester, 'Beine'), isTrue);
    expect(isSelected(tester, 'Oberkörper'), isFalse);
    await settle(tester);
    expect((await settings(tester)).lastSelectedPlanId, second);
    await disposeApp(tester, db);
  });

  testWidgets('picker marks contained exercises and adds the chosen one', (
    tester,
  ) async {
    final plan = await seedPlan(tester);
    await dbWork(
      tester,
      () => addExercise(
        r,
        'Kniebeuge',
        ExerciseType.weightReps,
        ExerciseCategory.legs,
      ),
    );
    await start(tester);
    await openPicker(tester);
    expect(find.text(S.alreadyAdded), findsNWidgets(3));
    expect(find.text(S.category(ExerciseCategory.legs)), findsOneWidget);

    // Search ignores case.
    await tester.enterText(
      find.widgetWithText(TextField, S.pickerSearchHint),
      'KNIE',
    );
    await tester.pumpAndSettle();
    final inSheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: inSheet, matching: find.text('Bankdrücken')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(of: inSheet, matching: find.text('Kniebeuge')),
    );
    await settle(tester);

    final entries = await dbWork(tester, () => r.plans.getEntries(plan));
    expect(entries.last.exercise.name, 'Kniebeuge');
    expect(entries.last.planExercise.targetSets, 3, reason: 'default sets');
    expect(find.text('Kniebeuge'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('"Neue Übung anlegen" creates the exercise and adds it', (
    tester,
  ) async {
    await dbWork(tester, () => r.plans.create('Spontan'));
    await start(tester);
    await openPicker(tester);
    await tester.enterText(
      find.widgetWithText(TextField, S.pickerSearchHint),
      'Seitstütz',
    );
    await tester.tap(find.text(S.createExercise));
    await tester.pumpAndSettle();

    // The name is prefilled from the search.
    expect(find.widgetWithText(TextField, 'Seitstütz'), findsOneWidget);
    await tester.tap(find.text(S.exerciseType(ExerciseType.timed)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('${S.fieldTargetDuration}: ${S.increase}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.save));
    await settle(tester);

    final created = (await dbWork(
      tester,
      () => r.exercises.watchActive().first,
    )).single;
    expect(created.type, ExerciseType.timed);
    expect(created.includeInStrengthIndex, isFalse);
    expect(find.text('Seitstütz'), findsOneWidget);
    expect(find.text('3 × 30 s'), findsOneWidget);

    await tester.tap(find.text(S.startTraining));
    await settle(tester);
    final session = await dbWork(tester, r.sessions.getActive);
    final details = await dbWork(
      tester,
      () => r.sessions.watchDetails(session!.id).first,
    );
    expect(details.single.sessionExercise.targetDurationSec, 30);
    await disposeApp(tester, db);
  });

  testWidgets('swipe removes a plan exercise, undo restores it', (
    tester,
  ) async {
    final plan = await seedPlan(tester);
    await start(tester);

    await tester.drag(find.text('Klimmzüge'), const Offset(-600, 0));
    await settle(tester);
    expect(find.text('Klimmzüge'), findsNothing);
    expect(find.text(S.removedFromList('Klimmzüge')), findsOneWidget);
    expect(await dbWork(tester, () => r.plans.getEntries(plan)), hasLength(2));

    await tester.tap(find.text(S.undo));
    await settle(tester);
    final names = (await dbWork(
      tester,
      () => r.plans.getEntries(plan),
    )).map((e) => e.exercise.name);
    expect(names, ['Bankdrücken', 'Klimmzüge', 'Plank']);
    expect(find.text('Klimmzüge'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('dragging the handle reorders the plan', (tester) async {
    final plan = await seedPlan(tester);
    await start(tester);

    final handle = find.byIcon(Icons.drag_handle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);

    final names = (await dbWork(
      tester,
      () => r.plans.getEntries(plan),
    )).map((e) => e.exercise.name).toList();
    expect(names.first, isNot('Bankdrücken'));
    expect(names, containsAll(['Bankdrücken', 'Klimmzüge', 'Plank']));
    await disposeApp(tester, db);
  });

  testWidgets('"Im Plan bearbeiten" saves each change immediately', (
    tester,
  ) async {
    final plan = await seedPlan(tester);
    await start(tester);
    await tester.tap(find.text('Bankdrücken'));
    await tester.pumpAndSettle();
    expect(find.text(S.editInPlan), findsOneWidget);
    await tester.tap(find.byTooltip('${S.fieldSets}: ${S.increase}'));
    await tester.tap(find.byTooltip('${S.fieldTargetReps}: ${S.decrease}'));
    await tester.tap(find.byTooltip('${S.fieldRestShort}: ${S.increase}'));
    await settle(tester);

    final p = (await dbWork(
      tester,
      () => r.plans.getEntries(plan),
    )).first.planExercise;
    expect((p.targetSets, p.targetReps, p.restSec), (4, 9, 105));

    await tester.tap(find.text(S.resetToDefault));
    await settle(tester);
    final reset = (await dbWork(
      tester,
      () => r.plans.getEntries(plan),
    )).first.planExercise;
    expect(reset.restSec, isNull);
    await disposeApp(tester, db);
  });

  testWidgets('long press opens the plan page: rename, delete (1.2.1)', (
    tester,
  ) async {
    await seedPlan(tester);
    await start(tester);

    await tester.longPress(find.text('Oberkörper'));
    await settle(tester);
    expect(find.text(S.planSchedule), findsOneWidget);
    await tester.tap(find.text(S.planNameLabel));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Push');
    await tester.tap(find.text(S.save));
    await settle(tester);
    expect(find.text('Push'), findsWidgets, reason: 'title and name');
    await leavePage(tester);
    expect(isSelected(tester, 'Push'), isTrue);

    await tester.longPress(find.text('Push'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text(S.delete),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(S.delete));
    await tester.pumpAndSettle();
    expect(find.text(S.deletePlanTitle('Push')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, S.delete));
    await settle(tester);

    expect(await dbWork(tester, r.plans.getPlans), isEmpty);
    expect(find.text(S.noPlansYet), findsOneWidget, reason: 'back, no plan');
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'no confirmation (1.0.1)',
    );
    await disposeApp(tester, db);
  });

  testWidgets('plan session keeps the plan name; discard without sets', (
    tester,
  ) async {
    await seedPlan(tester);
    await start(tester);
    await tester.tap(find.text(S.startTraining));
    await settle(tester);
    final session = (await dbWork(tester, r.sessions.getActive))!;
    expect(session.planNameSnapshot, 'Oberkörper');
    expect(find.text('Oberkörper'), findsOneWidget);

    await tester.tap(find.text(S.finishTraining));
    await tester.pumpAndSettle();
    expect(find.text(S.discardNoSetsTitle), findsOneWidget);
    await tester.tap(find.text(S.keepTraining));
    await tester.pumpAndSettle();
    expect(await dbWork(tester, r.sessions.getActive), isNotNull);

    await tester.tap(find.text(S.finishTraining));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.discard));
    await settle(tester);
    expect(await dbWork(tester, r.sessions.getActive), isNull);
    expect(await dbWork(tester, () => r.sessions.findById(session.id)), isNull);
    expect(find.text(S.startTraining), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('a deleted selected plan falls back to the first plan', (
    tester,
  ) async {
    final plan = await seedPlan(tester);
    await dbWork(tester, () => r.plans.create('Beine'));
    await start(tester);
    await dbWork(tester, () => r.plans.delete(plan));
    await settle(tester);
    expect(isSelected(tester, 'Beine'), isTrue);
    await disposeApp(tester, db);
  });
}
