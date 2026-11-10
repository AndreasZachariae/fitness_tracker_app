import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/core/router.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/records.dart';
import 'package:gymlog/domain/reminders.dart';
import 'package:gymlog/features/training/session/rest_timer_bar.dart';
import 'package:gymlog/features/training/session/session_tiles.dart';

import '../../helpers/fake_device.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// M4: rest timer, screen on, suggestion, records, exercise note.
void main() {
  late AppDatabase db;
  late Repos r;
  late FixedClock clock;
  late FakeFeedback feedback;
  late FakeScreenAwake screen;
  late FakeRestAlarm alarm;
  late FakeNotifications notifications;

  setUp(() {
    alarm = FakeRestAlarm();
    notifications = FakeNotifications();
    db = newTestDatabase();
    r = Repos(db);
    clock = newTestClock();
    feedback = FakeFeedback();
    screen = FakeScreenAwake();
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
      screen: screen,
      alarm: alarm,
      notifications: notifications,
    );
    await settle(tester);
  }

  /// One finished session with [lastSets] of bench, then a running session
  /// with bench (3 × [targetReps], rest 90 s).
  Future<int> seed(
    WidgetTester tester, {
    List<(double, int)> lastSets = const [(60, 10), (60, 10), (60, 10)],
    int? targetReps = 10,
  }) => dbWork(tester, () async {
    final bench = await addExercise(r, 'Bankdrücken');
    final old = SessionRepository(
      db,
      FixedClock(testNow.subtract(const Duration(days: 3))),
    );
    if (lastSets.isNotEmpty) {
      final id = await old.start(
        exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 3)],
      );
      final se = (await old.getDetails(id)).single.sessionExercise;
      for (final (kg, reps) in lastSets) {
        await old.addSet(se.id, weightKg: kg, reps: reps);
      }
      await old.finish(id);
    }
    return SessionRepository(db, clock).start(
      exercises: [
        SessionExerciseDraft(
          exerciseId: bench,
          targetSets: 3,
          targetReps: targetReps,
          restSec: 90,
        ),
      ],
    );
  });

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text(S.saveSet));
    await tester.tap(find.text(S.saveSet));
    await settle(tester);
  }

  group('rest timer (1.0.1)', () {
    int restOvers() => feedback.calls.where((c) => c == 'restOver').length;

    Future<void> lifecycle(
      WidgetTester tester,
      List<AppLifecycleState> states,
    ) async {
      for (final s in states) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
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

    testWidgets('no vibration after "Beenden" while the summary is open', (
      tester,
    ) async {
      await seed(tester);
      await open(tester);
      await tapSave(tester);
      expect(find.text(S.rest), findsOneWidget);
      await tester.tap(find.text(S.finishTraining));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, S.finishTraining));
      await settle(tester);
      expect(find.text(S.summaryTitle), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        clock.advance(const Duration(seconds: 30));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(restOvers(), 0);
      await disposeApp(tester, db);
    });

    testWidgets('a covered home screen does not vibrate for a stopped rest', (
      tester,
    ) async {
      // On the phone the summary covered the home screen before it learned
      // that the training was over; Riverpod pauses covered screens.
      await seed(tester);
      await open(tester);
      await tapSave(tester);
      // Any full page on top covers the home screen, like the summary.
      unawaited(
        GoRouter.of(tester.element(find.text(S.saveSet)))
            .push(AppRoutes.settings),
      );
      await settle(tester);
      expect(find.text(S.settings), findsWidgets);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final setIds = await dbWork(tester, () async {
        final active = (await r.sessions.getActive())!;
        return [
          for (final d in await r.sessions.getDetails(active.id))
            ...d.sets.map((s) => s.id),
        ];
      });
      container.read(restTimerProvider.notifier).skipAll(setIds);
      for (var i = 0; i < 4; i++) {
        clock.advance(const Duration(seconds: 30));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(restOvers(), 0);
      await disposeApp(tester, db);
    });

    testWidgets('background: alarm at the end of the rest; back after the '
        'end: no second vibration', (tester) async {
      await seed(tester);
      await open(tester);
      await tapSave(tester);
      clock.advance(const Duration(seconds: 30));
      await tester.pump(const Duration(milliseconds: 300));
      await lifecycle(tester, toBackground);
      expect(alarm.calls, ['schedule']);
      expect(alarm.scheduledAt, testNow.add(const Duration(seconds: 90)));
      // Countdown on the lock screen (1.2.0).
      final countdown = notifications.shown.single;
      expect(countdown.id, ReminderIds.rest);
      expect(countdown.at, testNow.add(const Duration(seconds: 90)));
      expect(countdown.title, S.notifyRestTitle);

      clock.advance(const Duration(seconds: 62));
      await lifecycle(tester, toForeground);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(alarm.calls, ['schedule', 'cancel']);
      expect(notifications.cancelled, contains(ReminderIds.rest));
      expect(find.text(S.restOver), findsOneWidget);
      expect(restOvers(), 0, reason: 'the alarm vibrated already');
      await disposeApp(tester, db);
    });

    testWidgets('back before the end: alarm cancelled, the app vibrates', (
      tester,
    ) async {
      await seed(tester);
      await open(tester);
      await tapSave(tester);
      await lifecycle(tester, toBackground);
      clock.advance(const Duration(seconds: 40));
      await lifecycle(tester, toForeground);
      expect(alarm.calls, ['schedule', 'cancel']);
      clock.advance(const Duration(seconds: 51));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(restOvers(), 1);
      await disposeApp(tester, db);
    });

    testWidgets('no alarm without a running rest or with vibration off', (
      tester,
    ) async {
      await seed(tester);
      await open(tester);
      await lifecycle(tester, toBackground);
      await lifecycle(tester, toForeground);
      expect(alarm.calls, isEmpty, reason: 'no set yet');

      await dbWork(
        tester,
        () =>
            SettingsRepository(db)
                .update((s) => s.copyWith(vibrationEnabled: false)),
      );
      await tapSave(tester);
      await lifecycle(tester, toBackground);
      expect(alarm.calls, isEmpty);
      await lifecycle(tester, toForeground);
      await disposeApp(tester, db);
    });
  });

  group('rest timer (SPEC §6.2.1)', () {
    testWidgets('starts after a set, ±15 s, counts down from stored time', (
      tester,
    ) async {
      await seed(tester);
      await open(tester);
      expect(find.text(S.rest), findsNothing);

      await tapSave(tester);
      expect(find.text(S.rest), findsOneWidget);
      expect(find.text('1:30'), findsOneWidget);

      await tester.tap(find.text(S.restPlus));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1:45'), findsOneWidget);
      await tester.tap(find.text(S.restMinus));
      await tester.tap(find.text(S.restMinus));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1:15'), findsOneWidget);

      clock.advance(const Duration(seconds: 30));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('0:45'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('at 0: vibrates once, "Pause vorbei" for 10 s', (tester) async {
      await seed(tester);
      await open(tester);
      await tapSave(tester);
      clock.advance(const Duration(seconds: 89));
      await tester.pump(const Duration(milliseconds: 300));
      expect(feedback.calls, isNot(contains('restOver')));

      clock.advance(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text(S.restOver), findsOneWidget);
      expect(feedback.calls.where((c) => c == 'restOver'), hasLength(1));

      clock.advance(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(S.restOver), findsOneWidget);
      expect(feedback.calls.where((c) => c == 'restOver'), hasLength(1));

      clock.advance(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(S.restOver), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('no vibration when switched off; skip hides the bar', (
      tester,
    ) async {
      await seed(tester);
      await dbWork(
        tester,
        () =>
            SettingsRepository(db)
                .update((s) => s.copyWith(vibrationEnabled: false)),
      );
      await open(tester);
      await tapSave(tester);
      clock.advance(const Duration(seconds: 91));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text(S.restOver), findsOneWidget);
      expect(feedback.calls, isNot(contains('restOver')));

      await tapSave(tester);
      expect(find.text(S.rest), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(RestTimerBar),
          matching: find.text(S.restSkip),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(S.rest), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('rest timer can be switched off', (tester) async {
      await seed(tester);
      await dbWork(
        tester,
        () =>
            SettingsRepository(db)
                .update((s) => s.copyWith(restTimerEnabled: false)),
      );
      await open(tester);
      await tapSave(tester);
      expect(find.text(S.rest), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('after a restart the remaining time is rebuilt', (
      tester,
    ) async {
      await seed(tester);
      await open(tester);
      await tapSave(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      clock.advance(const Duration(seconds: 40));
      await open(tester);
      expect(find.text('0:50'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('the bar is visible on other tabs too', (tester) async {
      await seed(tester);
      await open(tester);
      await tapSave(tester);
      await tester.tap(find.text(S.tabBody));
      await tester.pumpAndSettle();
      expect(find.text(S.rest), findsOneWidget);
      await disposeApp(tester, db);
    });
  });

  testWidgets('display stays on only during a session (keepScreenOn)', (
    tester,
  ) async {
    final id = await seed(tester);
    await open(tester);
    expect(screen.on, isTrue);
    await dbWork(
      tester,
      () =>
          SettingsRepository(db).update((s) => s.copyWith(keepScreenOn: false)),
    );
    await settle(tester);
    expect(screen.on, isFalse);
    await dbWork(
      tester,
      () =>
          SettingsRepository(db).update((s) => s.copyWith(keepScreenOn: true)),
    );
    await settle(tester);
    expect(screen.on, isTrue);
    await dbWork(tester, () => r.sessions.delete(id));
    await settle(tester);
    expect(screen.on, isFalse);
    await disposeApp(tester, db);
  });

  group('suggestion chip (SPEC §7.2)', () {
    testWidgets('offered for set 1; tap applies, then it is gone', (
      tester,
    ) async {
      await seed(tester);
      await open(tester);
      expect(find.text('60 kg'), findsOneWidget);
      expect(find.text(S.suggestion('+2,5 kg')), findsOneWidget);
      await tester.tap(find.text(S.suggestion('+2,5 kg')));
      await tester.pump();
      expect(find.text('62,5 kg'), findsOneWidget);
      expect(find.text(S.suggestion('+2,5 kg')), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('× dismisses without changing the values', (tester) async {
      await seed(tester);
      await open(tester);
      await tester.tap(find.byTooltip(S.dismissSuggestion));
      await tester.pump();
      expect(find.text(S.suggestion('+2,5 kg')), findsNothing);
      expect(find.text('60 kg'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('not offered when the target was missed', (tester) async {
      await seed(tester, lastSets: const [(60, 10), (60, 9), (60, 10)]);
      await open(tester);
      expect(find.textContaining('Vorschlag'), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('not offered from set 2 on', (tester) async {
      await seed(tester);
      await open(tester);
      await tapSave(tester);
      expect(find.textContaining('Vorschlag'), findsNothing);
      await disposeApp(tester, db);
    });
  });

  group('records (SPEC §7.7)', () {
    testWidgets('new record: label, medium haptic, summary', (tester) async {
      final id = await seed(tester);
      await open(tester);
      await tester.tap(find.text(S.suggestion('+2,5 kg')));
      await tester.pump();
      await tester.ensureVisible(find.text(S.saveSet));
      await tester.tap(find.text(S.saveSet));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      // Red flash right after the record …
      expect(
        tester
            .widget<ActiveExerciseCard>(find.byType(ActiveExerciseCard))
            .highlight,
        isTrue,
      );
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      // … and gone again shortly after.
      expect(
        tester
            .widget<ActiveExerciseCard>(find.byType(ActiveExerciseCard))
            .highlight,
        isFalse,
      );

      // Only timers vibrate (1.3.1).
      expect(feedback.calls, isEmpty);
      expect(find.text(S.record), findsOneWidget);

      // Same values again: not strictly greater → no new record label.
      await tapSave(tester);
      expect(feedback.calls, isEmpty);
      expect(find.text(S.record), findsOneWidget);

      final records = await dbWork(tester, () => r.sessions.sessionRecords(id));
      expect(records.map((e) => e.kind), [
        RecordKind.estimatedOneRepMax,
        RecordKind.weight,
      ]);
      expect(records.last.value, 62.5);

      await tester.tap(find.text(S.finishTraining));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, S.finishTraining));
      await settle(tester);
      expect(find.text(S.newRecords), findsOneWidget);
      expect(
        find.text('${S.recordKind(RecordKind.weight)}: 62,5 kg'),
        findsOneWidget,
      );
      await disposeApp(tester, db);
    });

    testWidgets('no records in the first session of an exercise', (
      tester,
    ) async {
      await seed(tester, lastSets: const []);
      await open(tester);
      await tester.tap(find.text('– kg'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '100');
      await tester.tap(find.text(S.ok));
      await tester.pumpAndSettle();
      await tapSave(tester);
      await tester.tap(find.byTooltip('${S.weight}: ${S.increase}'));
      await tester.pump();
      await tapSave(tester);
      expect(find.text(S.record), findsNothing);
      expect(feedback.calls, isNot(contains('record')));
      await disposeApp(tester, db);
    });
  });

  testWidgets('exercise note: add in the tile, shown in one line', (
    tester,
  ) async {
    await seed(tester);
    await open(tester);
    await tester.tap(find.text(S.addNote));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sitzhöhe 4, Griff eng');
    await tester.tap(find.text(S.save));
    await settle(tester);
    expect(find.text('Sitzhöhe 4, Griff eng'), findsOneWidget);
    final e = await dbWork(tester, () => r.exercises.findById(1));
    expect(e!.notes, 'Sitzhöhe 4, Griff eng');
    await disposeApp(tester, db);
  });
}
