import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/features/training/session/session_tiles.dart';
import 'package:gymlog/widgets/group_frame.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// Supersets and rotations in the training tab and the session (M9).
void main() {
  late AppDatabase db;
  late Repos r;
  late int planId;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
  });

  final superset = S.groupKind(PlanGroupKind.superset).toUpperCase();
  final rotation = S.groupKind(PlanGroupKind.rotation).toUpperCase();

  /// Plan "Push": Klimmzüge, Dips (bodyweight, 2 × 10), Curls A, Curls B.
  Future<void> seed(WidgetTester tester) => dbWork(tester, () async {
    final pull = await addExercise(r, 'Klimmzüge', ExerciseType.bodyweight);
    final dips = await addExercise(r, 'Dips', ExerciseType.bodyweight);
    final curlA = await addExercise(r, 'Curls Hantel', ExerciseType.bodyweight);
    final curlB = await addExercise(r, 'Curls Seil', ExerciseType.bodyweight);
    planId = await r.plans.create('Push');
    for (final e in [pull, dips, curlA, curlB]) {
      await r.plans.addExercise(planId, e, targetSets: 2, targetReps: 10);
    }
    await SettingsRepository(db)
        .update((s) => s.copyWith(lastSelectedPlanId: planId));
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db);
    await settle(tester);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle(tester);
  }

  /// "… erstellen" below the list, choose [names], confirm.
  Future<void> createGroup(
    WidgetTester tester,
    PlanGroupKind kind,
    List<String> names,
  ) async {
    await tester.dragUntilVisible(
      find.text(S.createGroup(kind)),
      find.byType(ReorderableListView).first,
      const Offset(0, -200),
    );
    await tester.tap(find.text(S.createGroup(kind)));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    for (final n in names) {
      await tester.tap(
        find.descendant(
          of: sheet,
          matching: find.widgetWithText(CheckboxListTile, n),
        ),
      );
      await tester.pump();
    }
    await tester.tap(
      find.descendant(
        of: sheet,
        matching: find.widgetWithText(FilledButton, S.createGroup(kind)),
      ),
    );
    await settle(tester);
  }

  String activeName(WidgetTester tester) => tester
      .widget<ActiveExerciseCard>(find.byType(ActiveExerciseCard))
      .detail
      .exercise
      .name;

  testWidgets('superset: create in the plan, alternate, rest after a round', (
    tester,
  ) async {
    await seed(tester);
    await open(tester);
    await createGroup(tester, PlanGroupKind.superset, ['Klimmzüge', 'Dips']);
    expect(find.text(superset), findsOneWidget);
    expect(find.text(S.supersetRestDefault), findsOneWidget);
    final groups = await dbWork(tester, () => r.plans.getGroups(planId));
    expect(groups.values.single.kind, PlanGroupKind.superset);

    await tester.tap(find.text(S.startTraining));
    await settle(tester);
    expect(find.text(superset), findsOneWidget);
    expect(
      find.text('${S.supersetRound(1, 2)} · ${S.supersetRestDefault}'),
      findsOneWidget,
    );
    expect(activeName(tester), 'Klimmzüge');

    await tapVisible(tester, find.text(S.saveSet));
    expect(activeName(tester), 'Dips', reason: 'on to the partner');
    expect(find.text(S.rest), findsNothing, reason: 'no rest within a round');

    await tapVisible(tester, find.text(S.saveSet));
    expect(activeName(tester), 'Klimmzüge');
    expect(find.text(S.rest), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget, reason: 'rest of the last one');
    expect(
      find.text('${S.supersetRound(2, 2)} · ${S.supersetRestDefault}'),
      findsOneWidget,
    );
    await disposeApp(tester, db);
  });

  testWidgets('superset options: rest, dissolve', (tester) async {
    await seed(tester);
    await open(tester);
    await createGroup(tester, PlanGroupKind.superset, ['Klimmzüge', 'Dips']);

    await tester.tap(find.byTooltip(S.groupOptions(PlanGroupKind.superset)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.supersetRestOption));
    await tester.pumpAndSettle();
    expect(find.text(S.supersetRestTitle), findsOneWidget, reason: 'title');
    expect(find.text(S.supersetRestDialogDefault), findsOneWidget);
    final dialogSize = tester.getSize(find.byType(AlertDialog));
    await tester.tap(find.byTooltip('${S.fieldRestShort}: ${S.increase}'));
    await tester.pump();
    expect(find.text(S.supersetRestDialogDefault), findsNothing);
    expect(find.text(S.resetToDefault), findsOneWidget);
    expect(
      tester.getSize(find.byType(AlertDialog)),
      dialogSize,
      reason: 'the dialog keeps its size (1.0.1)',
    );
    await tester.pump();
    await tester.tap(find.text(S.save));
    await settle(tester);
    expect(find.text(S.supersetRest('1:45 min')), findsOneWidget);
    expect(
      (await dbWork(
        tester,
        () => r.plans.getGroups(planId),
      )).values.single.restSec,
      105,
    );

    await tester.tap(find.byTooltip(S.groupOptions(PlanGroupKind.superset)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.dissolve));
    await settle(tester);
    expect(find.text(superset), findsNothing);
    expect(await dbWork(tester, () => r.plans.getGroups(planId)), isEmpty);
    await disposeApp(tester, db);
  });

  testWidgets('rotation: due exercise only, moves on after the training', (
    tester,
  ) async {
    await seed(tester);
    await open(tester);
    await createGroup(tester, PlanGroupKind.rotation, [
      'Curls Hantel',
      'Curls Seil',
    ]);
    expect(find.text(rotation), findsOneWidget);
    expect(find.text(S.rotationEvery(1)), findsOneWidget);
    expect(find.text(S.rotationDue), findsOneWidget);
    expect(find.text(S.rotationLater), findsOneWidget);

    await tester.tap(find.text(S.startTraining));
    await settle(tester);
    expect(find.text('Curls Hantel'), findsOneWidget);
    expect(find.text('Curls Seil'), findsNothing);

    // Train the due exercise, then finish.
    await tester.tap(find.text('Curls Hantel'));
    await settle(tester);
    await tapVisible(tester, find.text(S.saveSet));
    final session = await dbWork(tester, r.sessions.getActive);
    await dbWork(tester, () => r.sessions.finishSession(session!.id));
    await settle(tester);
    // The summary is not opened when finished elsewhere; back to planning.
    final groups = await dbWork(tester, () => r.plans.getGroups(planId));
    final curlB = (await dbWork(
      tester,
      () => r.plans.getEntries(planId),
    )).firstWhere((e) => e.exercise.name == 'Curls Seil').exercise.id;
    expect(groups.values.single.rotationExerciseId, curlB);
    await disposeApp(tester, db);
  });

  testWidgets('rotation interval dialog: compact, value shown once (1.0.1)', (
    tester,
  ) async {
    await seed(tester);
    await open(tester);
    await createGroup(tester, PlanGroupKind.rotation, [
      'Curls Hantel',
      'Curls Seil',
    ]);
    await tester.tap(find.byTooltip(S.groupOptions(PlanGroupKind.rotation)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.rotationEveryOption));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    // The visible card of the dialog.
    final card = find
        .descendant(of: dialog, matching: find.byType(Material))
        .first;
    expect(
      find.descendant(of: dialog, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text(S.trainingsUnit(1))),
      findsOneWidget,
    );
    final size = tester.getSize(card);
    await tester.tap(find.byTooltip('${S.rotationEveryTitle}: ${S.increase}'));
    await tester.pump();
    expect(
      find.descendant(of: dialog, matching: find.text(S.trainingsUnit(2))),
      findsOneWidget,
    );
    expect(find.text(S.rotationEvery(2)), findsNothing, reason: 'no repeat');
    expect(tester.getSize(card), size);
    expect(size.width, lessThan(340), reason: 'not stretched');
    await tester.tap(find.text(S.save));
    await settle(tester);
    expect(find.text(S.rotationEvery(2)), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('rotation: choose the next exercise in the sheet', (
    tester,
  ) async {
    await seed(tester);
    await open(tester);
    await createGroup(tester, PlanGroupKind.rotation, [
      'Curls Hantel',
      'Curls Seil',
    ]);
    await tapVisible(tester, find.text('Curls Seil'));
    await tester.tap(find.text(S.rotationMakeDue));
    await settle(tester);
    // Labels follow: "Curls Seil" is due now.
    final dueLabel = find.text(S.rotationDue);
    expect(
      find.ancestor(of: dueLabel, matching: find.byType(Card)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(dueLabel).dy,
      greaterThan(tester.getTopLeft(find.text('Curls Hantel')).dy),
    );
    final due = (await dbWork(
      tester,
      () => r.plans.getGroups(planId),
    )).values.single.rotationExerciseId;
    final entries = await dbWork(tester, () => r.plans.getEntries(planId));
    expect(
      entries.firstWhere((e) => e.exercise.id == due).exercise.name,
      'Curls Seil',
    );

    // "Aus Rotation nehmen" dissolves a rotation of two.
    await tapVisible(tester, find.text('Curls Hantel'));
    await tester.tap(find.text(S.removeFromGroup(PlanGroupKind.rotation)));
    await settle(tester);
    expect(find.text(rotation), findsNothing);
    await disposeApp(tester, db);
  });

  testWidgets('running session: create a superset of open exercises', (
    tester,
  ) async {
    await seed(tester);
    await open(tester);
    await tester.tap(find.text(S.startTraining));
    await settle(tester);
    expect(find.text(superset), findsNothing);
    await createGroup(tester, PlanGroupKind.superset, ['Dips', 'Curls Seil']);
    expect(find.text(superset), findsOneWidget);
    final session = await dbWork(tester, r.sessions.getActive);
    final details = await dbWork(
      tester,
      () => r.sessions.getDetails(session!.id),
    );
    expect(details.map((d) => d.exercise.name), [
      'Klimmzüge',
      'Dips',
      'Curls Seil',
      'Curls Hantel',
    ]);
    expect(details.map((d) => d.sessionExercise.supersetId != null), [
      false,
      true,
      true,
      false,
    ]);
    await disposeApp(tester, db);
  });

  Future<void> drag(WidgetTester tester, Finder handle, double dy) async {
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(Offset(0, dy / 12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
  }

  Future<List<String>> planOrder(WidgetTester tester) async => [
    for (final e in await dbWork(tester, () => r.plans.getEntries(planId)))
      e.exercise.name,
  ];

  testWidgets('a group moves as a whole; members move inside it', (
    tester,
  ) async {
    await seed(tester);
    await open(tester);
    await createGroup(tester, PlanGroupKind.superset, [
      'Curls Hantel',
      'Curls Seil',
    ]);
    expect(await planOrder(tester), [
      'Klimmzüge',
      'Dips',
      'Curls Hantel',
      'Curls Seil',
    ]);
    // Whole group to the top.
    await drag(tester, find.byType(GroupDragHandle), -400);
    expect(await planOrder(tester), [
      'Curls Hantel',
      'Curls Seil',
      'Klimmzüge',
      'Dips',
    ]);
    // Inside the group: second member above the first.
    final inner = find.descendant(
      of: find.ancestor(
        of: find.text('Curls Seil'),
        matching: find.byType(Card),
      ),
      matching: find.byIcon(Icons.drag_handle),
    );
    await drag(tester, inner, -120);
    expect(await planOrder(tester), [
      'Curls Seil',
      'Curls Hantel',
      'Klimmzüge',
      'Dips',
    ]);
    final groupIds = [
      for (final e in await dbWork(tester, () => r.plans.getEntries(planId)))
        e.planExercise.groupId,
    ];
    expect(groupIds[0], isNotNull);
    expect(groupIds[1], groupIds[0]);
    expect(groupIds.skip(2), [null, null]);
    await disposeApp(tester, db);
  });

  testWidgets('a held group shrinks to one line and lands between two '
      'single exercises (1.0.1)', (tester) async {
    await seed(tester);
    await open(tester);
    await createGroup(tester, PlanGroupKind.superset, [
      'Curls Hantel',
      'Curls Seil',
    ]);
    final handle = find.byType(GroupDragHandle);
    final dips = find.ancestor(
      of: find.text('Dips'),
      matching: find.byType(Card),
    );
    final dipsRect = tester.getRect(dips);
    final start = tester.getCenter(handle);
    final handleBelowTop =
        start.dy - tester.getTopLeft(find.byType(GroupFrame)).dy;

    final gesture = await tester.startGesture(start);
    await tester.pump();
    expect(
      find.text(groupCollapsedText(['Curls Hantel', 'Curls Seil'])),
      findsOneWidget,
      reason: 'collapsed while held',
    );
    // Top of the group into the upper half of "Dips".
    final target = dipsRect.top + dipsRect.height * 0.3 + handleBelowTop;
    const steps = 12;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(0, (target - start.dy) / steps));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Holding still must not make it jump on (it did with tall groups).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await settle(tester);
    expect(await planOrder(tester), [
      'Klimmzüge',
      'Curls Hantel',
      'Curls Seil',
      'Dips',
    ]);
    expect(find.text('Curls Hantel'), findsOneWidget, reason: 'expanded');
    expect(
      find.text(groupCollapsedText(['Curls Hantel', 'Curls Seil'])),
      findsNothing,
    );
    await disposeApp(tester, db);
  });

  testWidgets('a tap on the group handle collapses only while held', (
    tester,
  ) async {
    await seed(tester);
    await open(tester);
    await createGroup(tester, PlanGroupKind.superset, ['Klimmzüge', 'Dips']);
    await tester.tap(find.byType(GroupDragHandle));
    await settle(tester);
    expect(find.text(groupCollapsedText(['Klimmzüge', 'Dips'])), findsNothing);
    expect(find.text('Klimmzüge'), findsOneWidget);
    await disposeApp(tester, db);
  });
}
