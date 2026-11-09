import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/reminders.dart';
import 'package:gymlog/features/training/session/session_tiles.dart';

import '../../helpers/fake_device.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// 1.3.0: countdown for timed sets, lock screen, scrolling to the active
/// exercise.
void main() {
  late AppDatabase db;
  late Repos r;
  late FixedClock clock;
  late FakeFeedback feedback;
  late FakeRestAlarm alarm;
  late FakeNotifications notifications;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
    clock = newTestClock();
    feedback = FakeFeedback();
    alarm = FakeRestAlarm();
    notifications = FakeNotifications();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      db: db,
      clock: clock,
      feedback: feedback,
      alarm: alarm,
      notifications: notifications,
    );
    await settle(tester);
  }

  const toBackground = [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ];
  const toForeground = [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ];

  Future<void> lifecycle(
    WidgetTester tester,
    List<AppLifecycleState> states,
  ) async {
    for (final s in states) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump();
  }

  /// Running session with "Plank" (2 × 30 s, rest 60 s).
  Future<({int session, int exercise})> seedPlank(WidgetTester tester) =>
      dbWork(tester, () async {
        final plank = await addExercise(r, 'Plank', ExerciseType.timed);
        final session = await SessionRepository(db, clock).start(
          exercises: [
            SessionExerciseDraft(
              exerciseId: plank,
              targetSets: 2,
              targetDurationSec: 30,
              restSec: 60,
            ),
          ],
        );
        return (session: session, exercise: plank);
      });

  Future<List<SessionExerciseDetail>> details(WidgetTester tester, int id) =>
      dbWork(tester, () => r.sessions.getDetails(id));

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text(S.saveSet));
    await tester.tap(find.text(S.saveSet));
    await settle(tester);
  }

  final arrow = find.byKey(const ValueKey('timer-direction'));
  int restOvers() => feedback.calls.where((c) => c == 'restOver').length;

  testWidgets('countdown: arrow switches and is kept per exercise; at zero '
      'it vibrates and takes the full time', (tester) async {
    final ids = await seedPlank(tester);
    await open(tester);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await tester.tap(arrow);
    await settle(tester);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    final plank = await dbWork(
      tester,
      () => r.exercises.findById(ids.exercise),
    );
    expect(plank!.timerCountdown, isTrue);

    // Starts at the duration of the stepper (the plan target here).
    await tester.tap(find.text(S.stopwatchStart));
    await tester.pump();
    clock.advance(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0:20'), findsOneWidget);
    expect(
      tester.widget<IconButton>(arrow).onPressed,
      isNull,
      reason: 'fixed while running',
    );

    // The countdown ends on its own.
    clock.advance(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(find.text(S.stopwatchStop), findsNothing);
    expect(restOvers(), 1);
    await tapSave(tester);
    var sets = (await details(tester, ids.session)).single.sets;
    expect(sets.single.durationSec, 30);

    // Stopped early: the time done so far.
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text(S.stopwatchStart));
    await tester.tap(find.text(S.stopwatchStart));
    await tester.pump();
    clock.advance(const Duration(seconds: 12));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(S.stopwatchStop));
    await tester.pump();
    await tapSave(tester);
    sets = (await details(tester, ids.session)).single.sets;
    expect(sets.last.durationSec, 12);
    expect(restOvers(), 1);
    await disposeApp(tester, db);
  });

  testWidgets('a countdown on the lock screen: timer, alarm, "Zeit um"', (
    tester,
  ) async {
    final ids = await seedPlank(tester);
    await dbWork(
      tester,
      () => r.exercises.setTimerCountdown(ids.exercise, true),
    );
    await open(tester);
    await tester.tap(find.text(S.stopwatchStart));
    await tester.pump();
    clock.advance(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));

    await lifecycle(tester, toBackground);
    final end = testNow.add(const Duration(seconds: 30));
    expect(alarm.scheduledAt, end);
    final timer = notifications.shown.single;
    expect(
      (timer.id, timer.at, timer.payload),
      (ReminderIds.setTimer, end, 'countDown'),
    );
    expect(timer.title, 'Plank');
    final done = notifications.scheduled[ReminderIds.setTimerDone]!;
    expect((done.at, done.title), (end, S.notifySetTimerDoneTitle));

    await lifecycle(tester, toForeground);
    expect(alarm.calls.last, 'cancel');
    expect(
      notifications.cancelled,
      containsAll([ReminderIds.setTimer, ReminderIds.setTimerDone]),
    );
    await tester.tap(find.text(S.stopwatchStop));
    await tester.pump();
    await disposeApp(tester, db);
  });

  testWidgets('counting up on the lock screen: only the running time', (
    tester,
  ) async {
    await seedPlank(tester);
    await open(tester);
    await tester.tap(find.text(S.stopwatchStart));
    await tester.pump();
    await lifecycle(tester, toBackground);
    expect(alarm.calls, isEmpty);
    final timer = notifications.shown.single;
    expect((timer.at, timer.payload), (testNow, 'countUp'));
    expect(notifications.scheduled, isEmpty);
    await lifecycle(tester, toForeground);
    await tester.tap(find.text(S.stopwatchStop));
    await tester.pump();
    await disposeApp(tester, db);
  });

  testWidgets('starting the timer ends the rest', (tester) async {
    await seedPlank(tester);
    await open(tester);
    await tapSave(tester);
    expect(find.text(S.rest), findsOneWidget);
    await tester.ensureVisible(find.text(S.stopwatchStart));
    await tester.tap(find.text(S.stopwatchStart));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(S.rest), findsNothing);
    // No rest alarm in the background, only the set timer.
    await lifecycle(tester, toBackground);
    expect(alarm.calls, isEmpty);
    expect(notifications.shown.single.id, ReminderIds.setTimer);
    await lifecycle(tester, toForeground);
    await tester.tap(find.text(S.stopwatchStop));
    await tester.pump();
    await disposeApp(tester, db);
  });

  testWidgets('rest on the lock screen: countdown and "Pause vorbei", also '
      'with vibration off', (tester) async {
    await seedPlank(tester);
    await dbWork(
      tester,
      () =>
          SettingsRepository(db)
              .update((s) => s.copyWith(vibrationEnabled: false)),
    );
    await open(tester);
    await tapSave(tester);
    await lifecycle(tester, toBackground);
    final end = testNow.add(const Duration(seconds: 60));
    expect(alarm.calls, isEmpty, reason: 'vibration off');
    expect(notifications.shown.single.id, ReminderIds.rest);
    final done = notifications.scheduled[ReminderIds.restDone]!;
    expect((done.at, done.title), (end, S.notifyRestDoneTitle));
    await lifecycle(tester, toForeground);
    expect(notifications.scheduled, isEmpty);
    await disposeApp(tester, db);
  });

  testWidgets('a tapped exercise scrolls so that its start is visible', (
    tester,
  ) async {
    final names = [for (var i = 1; i <= 8; i++) 'Übung $i'];
    await dbWork(tester, () async {
      final drafts = [
        for (final n in names)
          SessionExerciseDraft(
            exerciseId: await addExercise(r, n),
            targetSets: 3,
            targetReps: 10,
          ),
      ];
      await SessionRepository(db, clock).start(exercises: drafts);
    });
    await open(tester);
    final target = find.text(names[5]);
    await tester.scrollUntilVisible(target, 300);
    await settle(tester);
    final before = tester.getTopLeft(target).dy;
    expect(before, greaterThan(250), reason: 'the scroll has to move it');
    await tester.tap(target);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final card = find.byType(ActiveExerciseCard);
    expect(
      find.descendant(of: card, matching: find.text(names[5])),
      findsOneWidget,
    );
    final listTop = tester
        .getTopLeft(
          find.ancestor(of: card, matching: find.byType(Scrollable)).first,
        )
        .dy;
    final top = tester.getTopLeft(card).dy;
    expect(top, greaterThanOrEqualTo(listTop - 1));
    expect(top, lessThan(listTop + 24), reason: 'its start at the top');
    await disposeApp(tester, db);
  });
}
