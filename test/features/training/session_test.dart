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

/// Session screen (SPEC §6.2, §6.3) incl. the widget tests of SPEC §10.
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
    // Phone size (392 × 851 dp) instead of the 800 × 600 test default.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db, clock: clock);
    await settle(tester);
  }

  /// Plan "Push" with bench (3 × 8, last time 60 kg) and pull-ups (2 × 8),
  /// session already started.
  Future<int> startPushSession(
    WidgetTester tester, {
    bool history = true,
  }) => dbWork(tester, () async {
    final bench = await addExercise(r, 'Bankdrücken');
    final pull = await addExercise(r, 'Klimmzüge', ExerciseType.bodyweight);
    if (history) {
      final old = await r.sessions.start(
        exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 2)],
      );
      final se = (await r.sessions.getDetails(old)).single.sessionExercise;
      await r.sessions.addSet(se.id, weightKg: 60, reps: 8);
      await r.sessions.addSet(se.id, weightKg: 60, reps: 7);
      await r.sessions.finish(old);
    }
    final planId = await r.plans.create('Push');
    await r.plans.addExercise(planId, bench, targetSets: 3, targetReps: 8);
    await r.plans.addExercise(planId, pull, targetSets: 2, targetReps: 8);
    final plan = (await r.plans.findById(planId))!;
    return SessionRepository(db, clock).start(
      plan: plan,
      exercises: [
        SessionExerciseDraft(exerciseId: bench, targetSets: 3, targetReps: 8),
        SessionExerciseDraft(exerciseId: pull, targetSets: 2, targetReps: 8),
      ],
    );
  });

  Future<List<SessionExerciseDetail>> details(WidgetTester tester, int id) =>
      dbWork(tester, () => r.sessions.getDetails(id));

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text(S.saveSet));
    await tester.tap(find.text(S.saveSet));
    await settle(tester);
  }

  testWidgets('flow: 3 sets → exercise done → finish → summary', (
    tester,
  ) async {
    final id = await startPushSession(tester);
    await open(tester);

    expect(find.text('Push'), findsOneWidget);
    expect(find.text(S.setOf(1, 3)), findsOneWidget);
    expect(find.text('Letztes Mal (1.11.): 60 × 8, 60 × 7'), findsNothing);
    expect(find.textContaining('Letztes Mal ('), findsOneWidget);
    // Prefill from the last session (§7.1 rule 2).
    expect(find.text('60 kg'), findsOneWidget);
    expect(find.text('8'), findsWidgets);

    for (var i = 0; i < 3; i++) {
      clock.advance(const Duration(minutes: 2));
      await tapSave(tester);
    }
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'no confirmation (1.0.1)',
    );
    final d = await details(tester, id);
    // §7.1 rule 1: each further set takes the values of the previous one.
    expect(d.first.sets.map((s) => (s.weightKg, s.reps)), [
      (60.0, 8),
      (60.0, 8),
      (60.0, 8),
    ]);
    expect(d.first.sessionExercise.status, SessionExerciseStatus.done);
    expect(find.text(S.doneSummary(3, '60 kg × 8')), findsOneWidget);
    // No automatic activation; the next open exercise is marked.
    expect(find.text(S.nextUp), findsOneWidget);
    expect(find.text(S.saveSet), findsNothing);

    await tester.tap(find.text(S.finishTraining));
    await tester.pumpAndSettle();
    expect(find.text(S.openExercisesTitle(1)), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, S.finishTraining));
    await settle(tester);

    expect(find.text(S.summaryTitle), findsOneWidget);
    expect(find.text('6 min'), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: 'sets');
    expect(find.text('1.440 kg'), findsOneWidget, reason: '3 × 60 × 8');
    expect(find.text(S.compareLast('+0 %')), findsNothing);
    final finished = (await dbWork(tester, () => r.sessions.findById(id)))!;
    expect(finished.endedAt, isNotNull);
    expect(
      (await details(tester, id)).last.sessionExercise.status,
      SessionExerciseStatus.skipped,
    );

    await tester.enterText(find.byType(TextField), 'Lief gut');
    await tester.tap(find.text(S.finished));
    await settle(tester);
    expect(find.text(S.startTraining), findsOneWidget);
    expect(
      (await dbWork(tester, () => r.sessions.findById(id)))!.notes,
      'Lief gut',
    );
    await disposeApp(tester, db);
  });

  testWidgets('empty weight: saving asks for it first', (tester) async {
    final id = await startPushSession(tester, history: false);
    await open(tester);
    expect(find.text('– kg'), findsOneWidget);
    await tester.ensureVisible(find.text(S.saveSet));
    await tester.tap(find.text(S.saveSet));
    await tester.pumpAndSettle();
    expect(find.text(S.enterWeight), findsOneWidget);
    await tester.enterText(find.byType(TextField), '62,5');
    await tester.tap(find.text(S.ok));
    await settle(tester);
    final set = (await details(tester, id)).first.sets.single;
    expect((set.weightKg, set.reps), (62.5, 8));
    expect(find.text('62,5 kg'), findsWidgets);
    await disposeApp(tester, db);
  });

  testWidgets('steppers change values; tap on a number for direct input', (
    tester,
  ) async {
    final id = await startPushSession(tester);
    await open(tester);
    // Two taps without a frame in between must both count.
    await tester.tap(find.byTooltip('${S.weight}: ${S.increase}'));
    await tester.tap(find.byTooltip('${S.reps}: ${S.decrease}'));
    await tester.pump();
    expect(find.text('62,5 kg'), findsOneWidget);
    await tester.tap(find.text('62,5 kg'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '70.5');
    await tester.tap(find.text(S.ok));
    await tester.pumpAndSettle();
    await tapSave(tester);
    final set = (await details(tester, id)).first.sets.single;
    expect((set.weightKg, set.reps), (70.5, 7));
    await disposeApp(tester, db);
  });

  testWidgets('tapping an open exercise activates it, the other keeps sets', (
    tester,
  ) async {
    final id = await startPushSession(tester);
    await open(tester);
    await tapSave(tester);
    await tester.ensureVisible(find.text('Klimmzüge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Klimmzüge'));
    await settle(tester);
    final d = await details(tester, id);
    expect(d.first.sessionExercise.status, SessionExerciseStatus.pending);
    expect(d.first.sets, hasLength(1));
    expect(d.last.sessionExercise.status, SessionExerciseStatus.active);
    expect(find.textContaining(S.progress(1, 3)), findsOneWidget);
    expect(find.text(S.addedWeight), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('done exercises have no drag handle and keep their place', (
    tester,
  ) async {
    final id = await dbWork(tester, () async {
      final a = await addExercise(r, 'A');
      final b = await addExercise(r, 'B');
      final c = await addExercise(r, 'C');
      return r.sessions.start(
        exercises: [
          for (final e in [a, b, c])
            SessionExerciseDraft(exerciseId: e, targetSets: 1),
        ],
      );
    });
    await dbWork(tester, () async {
      final first = (await r.sessions.getDetails(id)).first.sessionExercise;
      await r.sessions.saveSet(
        first.id,
        const SetValues(weightKg: 10, reps: 5),
      );
    });
    await open(tester);
    // A is done (no handle); B and C are open.
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));

    // Drag C to the very top: A must stay first.
    final handle = find.byIcon(Icons.drag_handle).last;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
    final names = (await details(tester, id)).map((d) => d.exercise.name);
    expect(names, ['A', 'C', 'B']);
    await disposeApp(tester, db);
  });

  testWidgets('done tile expands, set can be changed and reopened', (
    tester,
  ) async {
    final id = await startPushSession(tester);
    await open(tester);
    for (var i = 0; i < 3; i++) {
      await tapSave(tester);
    }
    await tester.tap(find.text('Bankdrücken'));
    await tester.pumpAndSettle();
    expect(find.text(S.reopen), findsOneWidget);

    await tester.tap(find.text('60 kg × 8').first);
    await tester.pumpAndSettle();
    expect(find.text(S.editSet(1)), findsOneWidget);
    await tester.tap(find.byTooltip('${S.reps}: ${S.increase}'));
    await tester.tap(find.widgetWithText(TextButton, S.save));
    await settle(tester);
    expect((await details(tester, id)).first.sets.first.reps, 9);

    await tester.tap(find.text(S.reopen));
    await settle(tester);
    expect(
      (await details(tester, id)).first.sessionExercise.status,
      SessionExerciseStatus.active,
    );
    await disposeApp(tester, db);
  });

  testWidgets('timed exercise: stopwatch takes the duration', (tester) async {
    final id = await dbWork(tester, () async {
      final plank = await addExercise(r, 'Plank', ExerciseType.timed);
      return SessionRepository(db, clock).start(
        exercises: [
          SessionExerciseDraft(
            exerciseId: plank,
            targetSets: 2,
            targetDurationSec: 45,
          ),
        ],
      );
    });
    await open(tester);
    expect(find.text('0:45'), findsOneWidget);
    await tester.tap(find.text(S.stopwatchStart));
    await tester.pump();
    clock.advance(const Duration(seconds: 52));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0:52'), findsOneWidget);
    await tester.tap(find.text(S.stopwatchStop));
    await tester.pump();
    expect(find.text('0:52'), findsOneWidget, reason: 'duration stepper');
    await tapSave(tester);
    final set = (await details(tester, id)).first.sets.single;
    expect((set.durationSec, set.reps), (52, null));
    await disposeApp(tester, db);
  });

  testWidgets('without sets "Beenden" offers to discard', (tester) async {
    final id = await startPushSession(tester);
    await open(tester);
    await tester.tap(find.text(S.finishTraining));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.discard));
    await settle(tester);
    expect(await dbWork(tester, () => r.sessions.findById(id)), isNull);
    expect(find.text(S.startTraining), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('other tabs show the running bar; tap returns', (tester) async {
    await startPushSession(tester);
    await open(tester);
    await tester.tap(find.text(S.tabStats));
    await tester.pumpAndSettle();
    expect(find.text(S.trainingRunning('0:00')), findsOneWidget);
    clock.advance(const Duration(minutes: 42, seconds: 13));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(S.trainingRunning('42:13')), findsOneWidget);
    await tester.tap(find.text(S.trainingRunning('42:13')));
    await tester.pumpAndSettle();
    expect(find.text(S.saveSet), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('app restart resumes exactly where it was', (tester) async {
    final id = await startPushSession(tester);
    await open(tester);
    await tapSave(tester);
    await tester.ensureVisible(find.text('Klimmzüge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Klimmzüge'));
    await settle(tester);
    // "Restart": a fresh widget tree on the same database.
    await tester.pumpWidget(const SizedBox.shrink());
    clock.advance(const Duration(minutes: 30));
    await open(tester);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('0:30:00'), findsOneWidget);
    expect(find.text(S.setOf(1, 2)), findsOneWidget, reason: 'Klimmzüge');
    expect(
      find.textContaining(S.progress(1, 3)),
      findsOneWidget,
      reason: 'Bankdrücken',
    );
    expect((await details(tester, id)).first.sets, hasLength(1));
    await disposeApp(tester, db);
  });

  testWidgets('forgotten session: "Beenden" ends 5 min after the last set', (
    tester,
  ) async {
    final id = await startPushSession(tester);
    clock.advance(const Duration(minutes: 20));
    await dbWork(tester, () async {
      final se = (await r.sessions.getDetails(id)).first.sessionExercise;
      await SessionRepository(
        db,
        clock,
      ).saveSet(se.id, const SetValues(weightKg: 60, reps: 8));
    });
    clock.advance(const Duration(hours: 13));
    await open(tester);

    expect(find.text(S.forgottenTitle('3.11.')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, S.finishTraining));
    await settle(tester);
    final s = (await dbWork(tester, () => r.sessions.findById(id)))!;
    expect(s.endedAt, testNow.add(const Duration(minutes: 25)));
    expect(find.text(S.summaryTitle), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('forgotten session: "Fortsetzen" and "Verwerfen"', (
    tester,
  ) async {
    final id = await startPushSession(tester);
    clock.advance(const Duration(hours: 13));
    await open(tester);
    await tester.tap(find.text(S.resume));
    await settle(tester);
    expect(await dbWork(tester, r.sessions.getActive), isNotNull);
    expect(find.text(S.saveSet), findsOneWidget);

    // Next app start asks again; discard needs a confirmation.
    await tester.pumpWidget(const SizedBox.shrink());
    await open(tester);
    await tester.tap(find.text(S.discard));
    await tester.pumpAndSettle();
    expect(find.text(S.discardConfirmTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, S.discard).last);
    await settle(tester);
    expect(await dbWork(tester, () => r.sessions.findById(id)), isNull);
    await disposeApp(tester, db);
  });

  testWidgets('summary: adopt the new order into the plan', (tester) async {
    final id = await startPushSession(tester, history: false);
    final plank = await dbWork(tester, () async {
      final p = await addExercise(r, 'Plank', ExerciseType.timed);
      await r.sessions.addExerciseToSession(
        id,
        p,
        const ExerciseTargets(sets: 1, durationSec: 30),
      );
      final se = (await r.sessions.getDetails(id)).first.sessionExercise;
      await r.sessions.saveSet(se.id, const SetValues(weightKg: 50, reps: 8));
      return p;
    });
    await open(tester);
    await tester.tap(find.text(S.finishTraining));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, S.finishTraining));
    await settle(tester);

    await tester.tap(find.text(S.adoptIntoPlan('Push')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.finished));
    await settle(tester);
    final entries = await dbWork(tester, () => r.plans.getEntries(1));
    expect(entries.map((e) => e.exercise.id), [1, 2, plank]);
    await disposeApp(tester, db);
  });

  testWidgets('summary: save a free training as a plan', (tester) async {
    final id = await dbWork(tester, () async {
      final e = await addExercise(r, 'Latzug');
      final id = await r.sessions.start(
        exercises: [SessionExerciseDraft(exerciseId: e, targetSets: 1)],
      );
      final se = (await r.sessions.getDetails(id)).single.sessionExercise;
      await r.sessions.saveSet(se.id, const SetValues(weightKg: 50, reps: 10));
      return id;
    });
    await open(tester);
    await tester.tap(find.text(S.finishTraining));
    await settle(tester);
    await tester.tap(find.text(S.saveAsPlan));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Rücken');
    await tester.tap(find.widgetWithText(TextButton, S.save));
    await settle(tester);
    expect(find.text(S.savedAsPlan('Rücken')), findsOneWidget);
    await tester.tap(find.text(S.finished));
    await settle(tester);

    final plans = await dbWork(tester, r.plans.getPlans);
    expect(plans.single.name, 'Rücken');
    expect(
      (await dbWork(tester, () => r.sessions.findById(id)))!.isFreeTraining,
      isTrue,
    );
    // The new plan is selected for the next training.
    expect(find.text('Latzug'), findsOneWidget);
    await disposeApp(tester, db);
  });
}
