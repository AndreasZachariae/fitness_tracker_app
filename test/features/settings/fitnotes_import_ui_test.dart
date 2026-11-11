import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/core/router.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/fake_files.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// 1.4.0: Settings → Pläne → "Plan aus FitNotes importieren".
void main() {
  final sample = File('test/fixtures/fitnotes_workout.txt').readAsBytesSync();

  late AppDatabase db;
  late Repos r;
  late FakeFileGateway files;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
    files = FakeFileGateway(Directory.systemTemp);
  });

  Future<void> openPlans(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db, files: files);
    // Also while a training runs (its screen has no gear).
    unawaited(
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push(AppRoutes.plans),
    );
    await settle(tester);
  }

  testWidgets('preview, own choice for one exercise, import, plan page', (
    tester,
  ) async {
    final bench = await dbWork(tester, () => addExercise(r, 'Bankdrücken'));
    final pushUps = await dbWork(
      tester,
      () => addExercise(r, 'Liegestütze', ExerciseType.bodyweight),
    );
    await openPlans(tester);
    files.nextPick = Uint8List.fromList(sample);
    await tester.tap(find.text(S.importFitNotes));
    await settle(tester);

    // Preview: name from the day, summary, the training of 2.11.
    expect(find.text(S.importFitNotesTitle), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Montag'), findsOneWidget);
    expect(find.text(S.importSummary(15, 47)), findsOneWidget);
    expect(find.text(S.importSkippedSets(2)), findsOneWidget);
    expect(find.text(S.importTrainingFrom('Mo, 2.11.2026')), findsOneWidget);
    // The bench press goes into the existing "Bankdrücken" by itself.
    expect(find.text(S.importExisting('Bankdrücken')), findsOneWidget);
    expect(
      find.text(S.importRotation('Weekly Rotate Chest Monday')),
      findsNWidgets(2),
    );

    // "Ring Push Up" → the existing "Liegestütze" instead of a new one.
    await tester.dragUntilVisible(
      find.text('Ring Push Up'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await tester.tap(find.text('Ring Push Up'));
    await settle(tester);
    expect(find.text(S.importCreateNew('Ring Push Up')), findsOneWidget);
    // Only exercises the sets fit: no "Bankdrücken" for reps only.
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Bankdrücken'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Liegestütze'));
    await settle(tester);
    expect(find.text(S.importExisting('Liegestütze')), findsOneWidget);

    await tester.tap(find.text(S.importStart));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    // The plan page opens for the training days.
    expect(find.text(S.planSchedule), findsOneWidget);
    final plan = await dbWork(
      tester,
      () async => (await r.plans.getPlans()).single,
    );
    expect(plan.name, 'Montag');
    final entries = await dbWork(tester, () => r.plans.getEntries(plan.id));
    expect(entries.map((e) => e.exercise.id), containsAll([bench, pushUps]));
    expect(entries, hasLength(15));
    final sessions = await dbWork(
      tester,
      () => r.sessions.watchFinished().first,
    );
    expect(sessions.single.planId, plan.id);
    await disposeApp(tester, db);
  });

  testWidgets('without training; plan name taken; not a FitNotes file', (
    tester,
  ) async {
    await dbWork(tester, () => r.plans.create('Montag'));
    await openPlans(tester);

    files.nextPick = Uint8List.fromList('Hallo'.codeUnits);
    await tester.tap(find.text(S.importFitNotes));
    await settle(tester);
    expect(find.text(S.importNotFitNotes), findsOneWidget);

    files.nextPick = Uint8List.fromList(sample);
    await tester.tap(find.text(S.importFitNotes));
    await settle(tester);
    // "Montag" exists: the next free name.
    final name = find.widgetWithText(TextField, 'Montag 2');
    expect(name, findsOneWidget);
    await tester.enterText(name, 'Montag');
    await tester.pump();
    expect(find.text(S.errorPlanNameTaken), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text(S.importStart),
              matching: find.byWidgetPredicate((w) => w is FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField).first, 'Brust & Rücken');
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await settle(tester);
    await tester.tap(find.text(S.importStart));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    final plans = await dbWork(tester, () => r.plans.getPlans());
    expect(plans.map((p) => p.name), ['Montag', 'Brust & Rücken']);
    final sessions = await dbWork(
      tester,
      () => r.sessions.watchFinished().first,
    );
    expect(sessions, isEmpty);
    await disposeApp(tester, db);
  });

  testWidgets('a running training: only the plan', (tester) async {
    await dbWork(tester, () async {
      final id = await addExercise(r, 'Bankdrücken');
      await r.sessions.start(
        exercises: [SessionExerciseDraft(exerciseId: id, targetSets: 1)],
      );
    });
    await openPlans(tester);
    files.nextPick = Uint8List.fromList(sample);
    await tester.tap(find.text(S.importFitNotes));
    await settle(tester);
    expect(find.text(S.importTrainingBlocked), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    await disposeApp(tester, db);
  });
}
