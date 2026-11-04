import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
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

  Future<void> openSettings(WidgetTester tester, String entry) async {
    await pumpApp(tester, db: db);
    await tester.tap(find.byTooltip(S.openSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry));
    await settle(tester);
  }

  /// Gives one exercise a finished session with one set.
  Future<void> train(int exerciseId) async {
    final id = await r.sessions.start(
      exercises: [SessionExerciseDraft(exerciseId: exerciseId, targetSets: 3)],
    );
    final se = (await r.sessions.watchDetails(id).first).single;
    await r.sessions.addSet(se.sessionExercise.id, weightKg: 60, reps: 10);
    await r.sessions.finish(id);
  }

  group('Übungen', () {
    Future<void> seed(WidgetTester tester) => dbWork(tester, () async {
      await addExercise(
        r,
        'Bankdrücken',
        ExerciseType.weightReps,
        ExerciseCategory.chest,
      );
      await addExercise(
        r,
        'Kniebeuge',
        ExerciseType.weightReps,
        ExerciseCategory.legs,
      );
      await addExercise(r, 'Plank', ExerciseType.timed, ExerciseCategory.core);
    });

    testWidgets('search and category filter', (tester) async {
      await seed(tester);
      await openSettings(tester, S.settingsExercises);
      expect(find.text('Bankdrücken'), findsOneWidget);
      expect(find.text('Plank'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'bankdrucken');
      await tester.pumpAndSettle();
      expect(find.text('Bankdrücken'), findsOneWidget, reason: 'ü = u');
      expect(find.text('Plank'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text(S.category(ExerciseCategory.legs)));
      await tester.pumpAndSettle();
      expect(find.text('Kniebeuge'), findsOneWidget);
      expect(find.text('Bankdrücken'), findsNothing);

      await tester.tap(find.text(S.allCategories));
      await tester.pumpAndSettle();
      expect(find.text('Bankdrücken'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('create with validation and duplicate check', (tester) async {
      await seed(tester);
      await openSettings(tester, S.settingsExercises);
      await tester.tap(find.text(S.newExercise));
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.save));
      await tester.pumpAndSettle();
      expect(find.text(S.errorNameRequired), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, S.fieldName),
        'kniebeuge',
      );
      await tester.tap(find.text(S.save));
      await settle(tester);
      expect(find.text(S.errorExerciseNameTaken), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, S.fieldName),
        'Klimmzüge',
      );
      await tester.tap(find.text(S.exerciseType(ExerciseType.bodyweight)));
      await tester.tap(find.text(S.category(ExerciseCategory.back)));
      await tester.enterText(
        find.widgetWithText(TextField, S.fieldIncrement),
        '1.25',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '${S.fieldRest} (${S.optional})'),
        '120',
      );
      await tester.tap(find.text(S.save));
      await settle(tester);

      final created = (await dbWork(
        tester,
        () => r.exercises.watchActive().first,
      )).firstWhere((e) => e.name == 'Klimmzüge');
      expect(created.type, ExerciseType.bodyweight);
      expect(created.category, ExerciseCategory.back);
      expect(created.incrementKg, 1.25);
      expect(created.restSec, 120);
      expect(created.includeInStrengthIndex, isTrue);
      expect(find.text('Klimmzüge'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('invalid increment and rest are rejected', (tester) async {
      await openSettings(tester, S.settingsExercises);
      await tester.tap(find.text(S.newExercise));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, S.fieldName), 'X');
      await tester.enterText(
        find.widgetWithText(TextField, S.fieldIncrement),
        '0',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '${S.fieldRest} (${S.optional})'),
        'abc',
      );
      await tester.tap(find.text(S.save));
      await tester.pumpAndSettle();
      expect(find.text(S.errorIncrement), findsOneWidget);
      expect(find.text(S.errorRest), findsOneWidget);
      expect(
        await dbWork(tester, () => r.exercises.watchActive().first),
        isEmpty,
      );
      await disposeApp(tester, db);
    });

    testWidgets('"Im Kraftindex" has an explanation (M9)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await openSettings(tester, S.settingsExercises);
      await tester.tap(find.text(S.newExercise));
      await tester.pumpAndSettle();
      final info = find.byTooltip('${S.explain}: ${S.strengthIndex}');
      await tester.scrollUntilVisible(
        info,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.textContaining('auch rückwirkend'), findsOneWidget);
      await tester.tap(find.text(S.ok));
      await tester.pumpAndSettle();
      expect(find.textContaining('auch rückwirkend'), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('edit; type is locked once trained', (tester) async {
      await seed(tester);
      await dbWork(tester, () => train(2));
      await openSettings(tester, S.settingsExercises);

      await tester.tap(find.text('Kniebeuge'));
      await settle(tester);
      expect(find.text(S.typeLocked), findsOneWidget);
      final timedChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, S.exerciseType(ExerciseType.timed)),
      );
      expect(timedChip.onSelected, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, S.fieldName),
        'Back Squat',
      );
      await tester.tap(find.text(S.save));
      await settle(tester);
      expect(find.text('Back Squat'), findsOneWidget);
      expect(
        (await dbWork(tester, () => r.exercises.findById(2)))!.name,
        'Back Squat',
      );
      await disposeApp(tester, db);
    });

    testWidgets('untrained exercise is deleted, trained one archived', (
      tester,
    ) async {
      await seed(tester);
      await dbWork(tester, () async {
        await train(1);
        final plan = await r.plans.create('Push');
        await r.plans.addExercise(plan, 1, targetSets: 3);
      });
      await openSettings(tester, S.settingsExercises);

      await tester.tap(find.text('Plank'));
      await settle(tester);
      await tester.tap(find.byTooltip(S.delete));
      await settle(tester);
      expect(find.text(S.deleteExerciseTitle('Plank')), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, S.delete));
      await settle(tester);
      expect(find.text(S.exerciseDeleted('Plank')), findsOneWidget);
      expect(await dbWork(tester, () => r.exercises.findById(3)), isNull);

      await tester.tap(find.text('Bankdrücken'));
      await settle(tester);
      await tester.tap(find.byTooltip(S.delete));
      await settle(tester);
      expect(find.text(S.archiveExerciseTitle('Bankdrücken')), findsOneWidget);
      expect(
        find.text(S.archiveExerciseBody + S.removedFromPlans(1)),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, S.archive));
      await settle(tester);
      expect(find.text(S.exerciseArchived('Bankdrücken')), findsOneWidget);
      expect(
        (await dbWork(tester, () => r.exercises.findById(1)))!.archived,
        isTrue,
      );

      // Archive → restore
      await tester.tap(find.byTooltip(S.openArchive));
      await settle(tester);
      expect(find.text('Bankdrücken'), findsOneWidget);
      await tester.tap(find.text(S.restore));
      await settle(tester);
      expect(find.text(S.archiveEmpty), findsOneWidget);
      expect(
        (await dbWork(tester, () => r.exercises.findById(1)))!.archived,
        isFalse,
      );
      await disposeApp(tester, db);
    });
  });

  group('Pläne', () {
    Future<void> seed(WidgetTester tester) => dbWork(tester, () async {
      final bench = await addExercise(r, 'Bankdrücken');
      final a = await r.plans.create('Oberkörper');
      await r.plans.create('Unterkörper');
      await r.plans.addExercise(a, bench, targetSets: 3);
    });

    testWidgets('list with exercise counts, create, rename, duplicate', (
      tester,
    ) async {
      await seed(tester);
      await openSettings(tester, S.settingsPlans);
      expect(find.text(S.exerciseCount(1)), findsOneWidget);
      expect(find.text(S.exerciseCount(0)), findsOneWidget);

      await tester.tap(find.text(S.newPlan));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Beine');
      await tester.tap(find.text(S.create));
      await settle(tester);
      expect(find.text('Beine'), findsOneWidget);

      await tester.tap(find.byTooltip(S.moreActions).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.duplicate));
      await tester.pumpAndSettle();
      expect(find.text(S.copyName('Oberkörper')), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, S.duplicate));
      await settle(tester);
      expect(find.text(S.copyName('Oberkörper')), findsOneWidget);
      expect(find.text(S.exerciseCount(1)), findsNWidgets(2));

      await tester.tap(find.byTooltip(S.moreActions).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.rename));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Push');
      await tester.tap(find.text(S.save));
      await settle(tester);
      final names = (await dbWork(tester, r.plans.getPlans)).map((p) => p.name);
      expect(names, ['Push', 'Unterkörper', 'Beine', 'Oberkörper (Kopie)']);
      await disposeApp(tester, db);
    });

    testWidgets('delete asks first and keeps the history', (tester) async {
      await seed(tester);
      await dbWork(tester, () async {
        final plan = (await r.plans.getPlans()).first;
        final id = await r.sessions.start(
          plan: plan,
          exercises: const [SessionExerciseDraft(exerciseId: 1, targetSets: 3)],
        );
        await r.sessions.finish(id);
      });
      await openSettings(tester, S.settingsPlans);

      await tester.tap(find.byTooltip(S.moreActions).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.delete));
      await tester.pumpAndSettle();
      expect(find.text(S.deletePlanBody), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, S.delete));
      await settle(tester);

      expect(find.text('Oberkörper'), findsNothing);
      final session = await dbWork(tester, () => r.sessions.findById(1));
      expect(session!.planNameSnapshot, 'Oberkörper');
      await disposeApp(tester, db);
    });

    testWidgets('drag changes the chip order', (tester) async {
      await seed(tester);
      await openSettings(tester, S.settingsPlans);
      final handle = find.byIcon(Icons.drag_handle).first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settle(tester);
      final names = (await dbWork(tester, r.plans.getPlans)).map((p) => p.name);
      expect(names, ['Unterkörper', 'Oberkörper']);
      await disposeApp(tester, db);
    });
  });
}
