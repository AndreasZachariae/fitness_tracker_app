import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/features/training/session/rest_timer_bar.dart';
import 'package:gymlog/features/training/session/set_input.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// 1.7.0: the training view "Optimiert für Trainingsgerätehalterung".
void main() {
  late AppDatabase db;
  late Repos r;
  late FixedClock clock;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
    clock = newTestClock();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db, clock: clock);
    await settle(tester);
  }

  Future<void> seed(WidgetTester tester, TrainingLayout layout) => dbWork(
    tester,
    () async {
      await SettingsRepository(db)
          .update((s) => s.copyWith(trainingLayout: layout));
      // Body weight: reps prefilled, saving needs no weight.
      final bench = await addExercise(r, 'Klimmzüge', ExerciseType.bodyweight);
      await SessionRepository(db, clock).start(
        exercises: [
          SessionExerciseDraft(
            exerciseId: bench,
            targetSets: 3,
            targetReps: 10,
            restSec: 90,
          ),
        ],
      );
    },
  );

  Future<void> saveSet(WidgetTester tester) async {
    await tester.ensureVisible(find.text(S.saveSet));
    await tester.tap(find.text(S.saveSet));
    await settle(tester);
  }

  double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  testWidgets('standard: save under the input, rest bar at the bottom', (
    tester,
  ) async {
    await seed(tester, TrainingLayout.standard);
    await open(tester);
    expect(
      top(tester, find.text(S.saveSet)),
      greaterThan(top(tester, find.byType(SetInput))),
    );
    await saveSet(tester);
    expect(find.byType(RestTimerBar), findsOneWidget);
    expect(
      top(tester, find.text(S.rest)),
      greaterThan(top(tester, find.text(S.saveSet))),
      reason: 'above the navigation bar',
    );
    await disposeApp(tester, db);
  });

  testWidgets('mount: save right under the name, rest bar under the timer; '
      'other tabs: bar at the bottom again', (tester) async {
    await seed(tester, TrainingLayout.mount);
    await open(tester);
    final save = find.text(S.saveSet);
    expect(top(tester, save), lessThan(top(tester, find.text(S.addOneSet))));
    expect(
      top(tester, save),
      lessThan(top(tester, find.text(S.addNote))),
      reason: 'before note and history',
    );
    await saveSet(tester);
    // One bar only, at the top above the exercise.
    expect(find.byType(RestTimerBar), findsOneWidget);
    expect(top(tester, find.text(S.rest)), lessThan(top(tester, save)));

    // On another tab the bar is back at the bottom (still one).
    await tester.tap(find.text(S.tabStats).last);
    await settle(tester);
    expect(find.byType(RestTimerBar), findsOneWidget);
    expect(
      top(tester, find.text(S.rest)),
      greaterThan(tester.view.physicalSize.height / 2.75 / 2),
    );
    await tester.tap(find.text(S.tabTraining).last);
    await settle(tester);
    expect(find.byType(RestTimerBar), findsOneWidget);
    expect(top(tester, find.text(S.rest)), lessThan(top(tester, save)));
    await disposeApp(tester, db);
  });

  testWidgets('settings → training: switch the view', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip(S.openSettings));
    await settle(tester);
    await tester.tap(find.text(S.sectionTraining).last);
    await settle(tester);
    final segment = find.text(S.trainingLayout(TrainingLayout.mount));
    await tester.ensureVisible(segment);
    await tester.pumpAndSettle();
    await tester.tap(segment);
    await settle(tester);
    final s = await dbWork(tester, () => SettingsRepository(db).get());
    expect(s.trainingLayout, TrainingLayout.mount);
    expect(
      find.text(S.trainingLayoutHint(TrainingLayout.mount)),
      findsOneWidget,
    );
    await disposeApp(tester, db);
  });
}
