import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/domain/exercise_library.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/features/settings/exercises/exercise_form_page.dart';

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

    testWidgets('adds the built-in library once', (tester) async {
      await dbWork(
        tester,
        () => addExercise(
          r,
          'Bankdrücken',
          ExerciseType.bodyweight,
          ExerciseCategory.other,
        ),
      );
      await openSettings(tester, S.settingsExercises);
      await tester.tap(find.byTooltip(S.addLibrary));
      await settle(tester);
      final missing = exerciseLibrary.length - 1;
      expect(find.text(S.addLibraryBody(missing)), findsOneWidget);
      await tester.tap(find.text(S.addLibraryConfirm));
      await settle(tester);
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'no confirmation (1.0.1)',
      );
      expect(find.text('Abduktoren (Maschine)'), findsOneWidget);
      final all = await dbWork(tester, () => db.exercisesDao.getAll());
      expect(all, hasLength(exerciseLibrary.length));
      expect(
        all.singleWhere((e) => e.name == 'Bankdrücken').type,
        ExerciseType.bodyweight,
        reason: 'own exercise unchanged',
      );

      await tester.tap(find.byTooltip(S.addLibrary));
      await settle(tester);
      expect(find.text(S.libraryComplete), findsOneWidget);
      expect(find.text(S.addLibraryConfirm), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('cancelling the library dialog adds nothing', (tester) async {
      await openSettings(tester, S.settingsExercises);
      expect(find.text(S.exercisesEmpty), findsOneWidget);
      await tester.tap(find.byTooltip(S.addLibrary));
      await settle(tester);
      await tester.tap(find.text(S.cancel));
      await settle(tester);
      expect(find.text(S.exercisesEmpty), findsOneWidget);
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
      await tester.ensureVisible(find.text(S.stepCustom));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.stepCustom));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, '${S.fieldStepValue} (kg)'),
        '1.25',
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, '${S.fieldRest} (${S.optional})'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ExerciseFormPage),
              matching: find.byType(Scrollable),
            )
            .first,
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
      expect(created.stepMode, StepMode.kg);
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
      await tester.ensureVisible(find.text(S.stepCustom));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.stepCustom));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, '${S.fieldStepValue} (kg)'),
        '0',
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, '${S.fieldRest} (${S.optional})'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ExerciseFormPage),
              matching: find.byType(Scrollable),
            )
            .first,
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

    testWidgets('weight steps: standard by default, lbs, levels (1.1.0)', (
      tester,
    ) async {
      Future<Exercise> create(
        String name,
        Future<void> Function() choose,
      ) async {
        await tester.tap(find.text(S.newExercise));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, S.fieldName),
          name,
        );
        await choose();
        await tester.tap(find.text(S.save));
        await settle(tester);
        return (await dbWork(
          tester,
          () => r.exercises.watchActive().first,
        )).firstWhere((e) => e.name == name);
      }

      await openSettings(tester, S.settingsExercises);
      final standard = await create('Gerät', () async {
        expect(find.text(S.stepStandardHint('15 lbs')), findsOneWidget);
      });
      expect(standard.stepMode, StepMode.standard);

      final lbs = await create('Andere Marke', () async {
        await tester.ensureVisible(find.text(S.stepCustom));
        await tester.pumpAndSettle();
        await tester.tap(find.text(S.stepCustom));
        await tester.pump();
        await tester.ensureVisible(find.text(S.unitLbs));
        await tester.pumpAndSettle();
        await tester.tap(find.text(S.unitLbs));
        await tester.pump();
        expect(find.text(S.stepLbsHint), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, '${S.fieldStepValue} (lbs)'),
          '10',
        );
      });
      expect((lbs.stepMode, lbs.incrementLbs), (StepMode.lbs, 10));

      final levels = await create('Seilzug', () async {
        await tester.ensureVisible(find.text(S.stepLevels));
        await tester.pumpAndSettle();
        await tester.tap(find.text(S.stepLevels));
        await tester.pump();
        await tester.enterText(
          find.widgetWithText(TextField, S.fieldLevelKg),
          '4,5',
        );
      });
      expect((levels.stepMode, levels.levelKg), (StepMode.levels, 4.5));

      final noKg = await create('Stufen ohne kg', () async {
        await tester.ensureVisible(find.text(S.stepLevels));
        await tester.pumpAndSettle();
        await tester.tap(find.text(S.stepLevels));
        await tester.pump();
      });
      expect((noKg.stepMode, noKg.levelKg), (StepMode.levels, null));
      await disposeApp(tester, db);
    });

    testWidgets('"Stufen" only for weight × reps', (tester) async {
      await openSettings(tester, S.settingsExercises);
      await tester.tap(find.text(S.newExercise));
      await tester.pumpAndSettle();
      expect(find.text(S.stepLevels), findsOneWidget);
      await tester.tap(find.text(S.exerciseType(ExerciseType.bodyweight)));
      await tester.pump();
      expect(find.text(S.stepLevels), findsNothing);
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
      expect(find.textContaining('neu berechnet'), findsOneWidget);
      await tester.tap(find.text(S.ok));
      await tester.pumpAndSettle();
      expect(find.textContaining('neu berechnet'), findsNothing);
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
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'no confirmation (1.0.1)',
      );
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
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'no confirmation (1.0.1)',
      );
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
    /// Scrolls the plan page until [text] is on screen.
    Future<void> reveal(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
    }

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
      // With the training days since 1.2.0.
      expect(
        find.text('${S.exerciseCount(1)} · ${S.noTrainingDays}'),
        findsOneWidget,
      );
      expect(
        find.text('${S.exerciseCount(0)} · ${S.noTrainingDays}'),
        findsOneWidget,
      );

      await tester.tap(find.text(S.newPlan));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Beine');
      await tester.tap(find.text(S.create));
      await settle(tester);
      await leavePage(tester);
      expect(find.text('Beine'), findsOneWidget);

      // No "⋮" menu any more: tapping a plan opens its page (1.2.1).
      expect(find.byTooltip(S.moreActions), findsNothing);
      await tester.tap(find.text('Oberkörper'));
      await settle(tester);
      await reveal(tester, S.duplicate);
      await tester.tap(find.text(S.duplicate));
      await tester.pumpAndSettle();
      expect(find.text(S.copyName('Oberkörper')), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, S.duplicate));
      await settle(tester);
      // The page of the copy replaces the original's page.
      expect(find.text(S.copyName('Oberkörper')), findsWidgets);
      await leavePage(tester);
      expect(
        find.text('${S.exerciseCount(1)} · ${S.noTrainingDays}'),
        findsNWidgets(2),
      );

      await tester.tap(find.text('Oberkörper'));
      await settle(tester);
      await tester.tap(find.text(S.planNameLabel));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Push');
      await tester.tap(find.text(S.save));
      await settle(tester);
      await leavePage(tester);
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

      await tester.tap(find.text('Oberkörper'));
      await settle(tester);
      await reveal(tester, S.delete);
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
