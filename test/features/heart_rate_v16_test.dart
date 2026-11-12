import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/heart_rate_repository.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/features/heart_rate/range_colors.dart';
import 'package:gymlog/features/settings/exercises/exercise_form_page.dart';
import 'package:gymlog/features/training/session/cardio_timer.dart';

import '../helpers/fake_device.dart';
import '../helpers/pump_app.dart';
import '../helpers/seed.dart';
import '../helpers/test_db.dart';

/// 1.6.0: heart rate profile, ranges, warning, pause by heart rate, cardio.
void main() {
  late AppDatabase db;
  late Repos r;
  late FixedClock clock;
  late FakeHeartRateMonitor monitor;
  late FakeFeedback feedback;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
    clock = newTestClock();
    monitor = FakeHeartRateMonitor();
    feedback = FakeFeedback();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      db: db,
      clock: clock,
      heartRate: monitor,
      feedback: feedback,
    );
    await settle(tester);
  }

  Future<void> profile(
    WidgetTester tester, {
    int hrMax = 185,
    int? warn,
    String? device = 'AA:01',
  }) => dbWork(
    tester,
    () => SettingsRepository(db).update(
      (s) => s.copyWith(hrMax: hrMax, hrWarnBpm: warn, hrDeviceId: device),
    ),
  );

  Future<void> beat(WidgetTester tester, int bpm) async {
    monitor.beat(bpm);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('Körper: enter the maximum, see Garmin ranges', (tester) async {
    await open(tester);
    await tester.tap(find.text(S.tabBody).last);
    await settle(tester);
    final card = find.byKey(const ValueKey('heart-rate-profile'));
    await tester.dragUntilVisible(
      card,
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(find.text(S.hrProfileEmpty), findsOneWidget);
    await tester.tap(find.text(S.hrProfileSet));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('hr-max')), '185');
    await tester.pump();
    // The suggestions follow the maximum.
    expect(find.text(S.hrWarnHint(176)), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('hr-birth')), '1990');
    await tester.tap(find.text(S.hrSexLabel(Sex.male)));
    // The weight input below also has "Speichern".
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(S.save),
      ),
    );
    await settle(tester);

    final s = await dbWork(tester, () => SettingsRepository(db).get());
    expect(
      (s.hrMax, s.birthYear, s.sex, s.hrWarnBpm),
      (185, 1990, Sex.male, null),
    );
    await tester.dragUntilVisible(
      find.text(S.hrRange(5)),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(find.text(S.hrRangeBpm(111, 129)), findsOneWidget);
    expect(find.text(S.hrWarnOff), findsOneWidget);
    expect(find.text('111 ${S.unitBpm}'), findsOneWidget, reason: 'pause');
    await disposeApp(tester, db);
  });

  testWidgets('exercise form: pause by heart rate and a warm-up target', (
    tester,
  ) async {
    await profile(tester);
    await open(tester);
    await tester.tap(find.byTooltip(S.openSettings));
    await settle(tester);
    await tester.tap(find.text(S.settingsExercises));
    await settle(tester);
    await tester.tap(find.text(S.newExercise));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, S.fieldName),
      'Ergometer',
    );
    await tester.tap(find.text(S.exerciseType(ExerciseType.timed)));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseFormPage), findsOneWidget);
    Future<void> tapVisible(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await tapVisible(find.byKey(const ValueKey('rest-by-hr')));
    await tapVisible(find.text(S.hrTargetRangeKind));
    // The ranges show their bpm with the profile.
    await tapVisible(find.textContaining(S.hrRangeBpm(111, 129)));
    final minutes = find.byKey(const ValueKey('hr-target-minutes'));
    await tester.ensureVisible(minutes);
    await tester.enterText(minutes, '6');
    await tapVisible(find.text(S.save).last);
    await settle(tester);
    await settle(tester);

    final e = (await dbWork(
      tester,
      () => r.exercises.getAll(),
    )).firstWhere((x) => x.name == 'Ergometer');
    expect(
      (e.restByHeartRate, e.hrTargetRange, e.hrTargetBpm, e.hrTargetMinutes),
      (true, 2, null, 6),
    );
    expect(e.hasHeartRateTarget, isTrue);
    await disposeApp(tester, db);
  });

  testWidgets('training: range color, warning at most every 2 minutes', (
    tester,
  ) async {
    await profile(tester, warn: 176);
    await dbWork(tester, () async {
      final bench = await addExercise(r, 'Bankdrücken');
      await SessionRepository(db, clock).start(
        exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 3)],
      );
    });
    await open(tester);
    await beat(tester, 115);
    final heart = tester.widget<Icon>(find.byIcon(Icons.favorite).first);
    expect(heart.color, rangeColor(2));
    expect(find.byKey(const ValueKey('heart-rate-warning')), findsNothing);

    await beat(tester, 180);
    expect(find.byKey(const ValueKey('heart-rate-warning')), findsOneWidget);
    expect(feedback.calls, ['heartRateWarning']);
    clock.advance(const Duration(minutes: 1));
    await beat(tester, 182);
    expect(feedback.calls, hasLength(1), reason: 'not again so soon');
    clock.advance(const Duration(minutes: 1, seconds: 1));
    await beat(tester, 181);
    expect(feedback.calls, ['heartRateWarning', 'heartRateWarning']);
    await disposeApp(tester, db);
  });

  testWidgets('pause by heart rate: ends below the limit, not before 30 s', (
    tester,
  ) async {
    await profile(tester);
    await dbWork(tester, () async {
      final bench = await r.exercises.create(
        const ExerciseDraft(
          name: 'Bankdrücken',
          type: ExerciseType.weightReps,
          restByHeartRate: true,
        ),
      );
      final id = await SessionRepository(db, clock).start(
        exercises: [
          SessionExerciseDraft(exerciseId: bench, targetSets: 3, restSec: 180),
        ],
      );
      final se = (await r.sessions.getDetails(id)).single.sessionExercise;
      await SessionRepository(db, clock).addSet(se.id, weightKg: 60, reps: 10);
    });
    await open(tester);
    expect(find.text(S.rest), findsOneWidget);
    expect(find.byKey(const ValueKey('rest-hr-limit')), findsOneWidget);

    // Below the limit, but too early.
    clock.advance(const Duration(seconds: 10));
    await beat(tester, 100);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text(S.rest), findsOneWidget);

    clock.advance(const Duration(seconds: 25));
    await beat(tester, 100);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(S.restOver), findsOneWidget);
    expect(feedback.calls, contains('restOver'));
    await disposeApp(tester, db);
  });

  testWidgets('cardio: only time in the target counts; reached → vibrates', (
    tester,
  ) async {
    await profile(tester);
    await dbWork(tester, () async {
      final bike = await r.exercises.create(
        const ExerciseDraft(
          name: 'Ergometer',
          type: ExerciseType.timed,
          hrTargetBpm: 120,
          hrTargetMinutes: 1,
        ),
      );
      await SessionRepository(db, clock).start(
        exercises: [SessionExerciseDraft(exerciseId: bike, targetSets: 1)],
      );
    });
    await open(tester);
    expect(find.byType(CardioTimer), findsOneWidget);
    expect(find.text(S.cardioGoal(S.hrTargetAtLeast(120), 1)), findsOneWidget);
    await beat(tester, 110);
    await tester.tap(find.text(S.stopwatchStart));
    await tester.pump();

    // 20 s below the target: the time stands.
    for (var i = 0; i < 40; i++) {
      clock.advance(CardioTimer.tick);
      await tester.pump(CardioTimer.tick);
    }
    expect(find.text(S.cardioOutsideTarget), findsOneWidget);
    expect(find.text('0:00 / 1:00'), findsOneWidget);

    await beat(tester, 125);
    for (var i = 0; i < 121; i++) {
      clock.advance(CardioTimer.tick);
      await tester.pump(CardioTimer.tick);
    }
    expect(find.byKey(const ValueKey('cardio-reached')), findsOneWidget);
    expect(feedback.calls, contains('restOver'));
    // The whole duration (about 80 s) goes to the duration stepper.
    expect(find.text('1:20'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('without a monitor a cardio target counts down the minutes', (
    tester,
  ) async {
    await profile(tester, device: null);
    await dbWork(tester, () async {
      final bike = await r.exercises.create(
        const ExerciseDraft(
          name: 'Ergometer',
          type: ExerciseType.timed,
          hrTargetRange: 2,
          hrTargetMinutes: 8,
        ),
      );
      await SessionRepository(db, clock).start(
        exercises: [SessionExerciseDraft(exerciseId: bike, targetSets: 1)],
      );
    });
    await open(tester);
    expect(find.byType(CardioTimer), findsNothing);
    expect(find.text('8:00'), findsWidgets, reason: 'countdown start');
    await disposeApp(tester, db);
  });

  testWidgets('summary: time in ranges, recovery and calories', (tester) async {
    final id = await dbWork(tester, () async {
      await SettingsRepository(
        db,
      ).update((s) => s.copyWith(hrMax: 185, birthYear: 1990, sex: Sex.male));
      final bench = await addExercise(r, 'Bankdrücken');
      final sessions = SessionRepository(db, clock);
      final id = await sessions.start(
        exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 1)],
      );
      final se = (await sessions.getDetails(id)).single.sessionExercise;
      DateTime t(int s) => testNow.add(Duration(seconds: s));
      await HeartRateRepository(db).addSamples(id, [
        for (var s = 0; s < 60; s++) (at: t(s), bpm: 150),
        (at: t(60), bpm: 165),
        for (var s = 61; s <= 130; s++) (at: t(s), bpm: 125),
      ]);
      clock.time = t(50);
      await sessions.addSet(se.id, weightKg: 80, reps: 5);
      clock.time = t(140);
      await sessions.finishSession(id);
      return id;
    });
    await open(tester);
    await tester.tap(find.text(S.tabHistory));
    await settle(tester);
    await tester.tap(find.textContaining('Di, 3.11.'));
    await settle(tester);
    final ranges = find.byKey(const ValueKey('heart-rate-ranges'));
    await tester.dragUntilVisible(
      ranges,
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(find.text(S.hrRange(4)), findsOneWidget);
    expect(find.text(S.heartRateRecoveryValue(40)), findsOneWidget);
    // Without a body weight no calories.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('heart-rate-calories')),
        matching: find.text('–'),
      ),
      findsOneWidget,
    );
    expect(id, isPositive);
    await disposeApp(tester, db);
  });
}
