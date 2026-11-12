import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/body_weight_repository.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/records.dart';
import 'package:gymlog/domain/statistics.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// Tab "Statistik" (SPEC §6.5).
void main() {
  late AppDatabase db;
  late Repos r;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
  });

  Future<void> openStats(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db);
    await settle(tester);
    await tester.tap(find.text(S.tabStats).last);
    await settle(tester);
  }

  /// Since 1.5.1 the statistics start on "Gesamt".
  Future<void> openExerciseTab(WidgetTester tester) async {
    await tester.tap(find.text(S.statsTabExercise));
    await settle(tester);
  }

  /// Bench on 1.9. (60 × 10), 20.10. (62,5 × 10), 30.10. (65 × 8);
  /// plank on 30.10.
  Future<void> seed(WidgetTester tester) => dbWork(tester, () async {
    final bench = await addExercise(r, 'Bankdrücken');
    final plank = await addExercise(r, 'Plank', ExerciseType.timed);
    Future<void> at(String day, Map<int, List<SetValues>> sets) async {
      final d = LocalDate.parse(day);
      final clock = FixedClock(DateTime(d.year, d.month, d.day, 18).toUtc());
      final repo = SessionRepository(db, clock);
      final id = await repo.start(
        exercises: [
          for (final e in sets.keys)
            SessionExerciseDraft(exerciseId: e, targetSets: 3),
        ],
      );
      final details = await repo.getDetails(id);
      for (final dt in details) {
        for (final v in sets[dt.exercise.id]!) {
          clock.advance(const Duration(minutes: 3));
          await repo.addSet(
            dt.sessionExercise.id,
            weightKg: v.weightKg,
            reps: v.reps,
            durationSec: v.durationSec,
          );
        }
      }
      clock.advance(const Duration(minutes: 40));
      await repo.finishSession(id);
    }

    await at('2026-09-01', {
      bench: [const SetValues(weightKg: 60, reps: 10)],
    });
    await at('2026-10-20', {
      bench: [const SetValues(weightKg: 62.5, reps: 10)],
    });
    await at('2026-10-30', {
      bench: [const SetValues(weightKg: 65, reps: 8)],
      plank: [const SetValues(durationSec: 60)],
    });
  });

  testWidgets('empty state', (tester) async {
    await openStats(tester);
    expect(find.text(S.statsNoData), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('exercise tab: most recent exercise, chart, figures', (
    tester,
  ) async {
    await seed(tester);
    await openStats(tester);
    await openExerciseTab(tester);
    // Most recently trained exercise first: bench and plank on 30.10. →
    // bench comes first in the session.
    expect(find.text('Bankdrücken'), findsWidgets);
    expect(
      find.text(S.metric(ExerciseMetric.estimatedOneRepMax)),
      findsWidgets,
    );
    expect(find.byType(LineChart), findsOneWidget);
    // e1RM: 80, 83,3, 82,3 → best 83,3; change +2,3 kg (+3 %)
    expect(find.text('83,3 kg'), findsWidgets);
    expect(find.text('+2,3 kg\n(+3\u00A0%)'), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: '3 trainings in 3 M');

    await tester.tap(find.text(S.metric(ExerciseMetric.maxWeight)));
    await tester.pumpAndSettle();
    expect(find.text('+5 kg\n(+8\u00A0%)'), findsOneWidget);

    await tester.tap(find.text(S.period4w));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget, reason: '1.9. is outside 4 W');
    expect(find.text('+2,5 kg\n(+4\u00A0%)'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('choose another exercise; too few points → hint', (tester) async {
    await seed(tester);
    await openStats(tester);
    await openExerciseTab(tester);
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plank').last);
    await tester.pumpAndSettle();
    expect(find.text(S.metric(ExerciseMetric.maxDuration)), findsWidgets);
    expect(find.text(S.statsSeriesEmpty), findsOneWidget);
    expect(find.text('1:00 min'), findsWidgets);
    await disposeApp(tester, db);
  });

  testWidgets('overall tab: index, streak, body weight, calendar', (
    tester,
  ) async {
    await seed(tester);
    await dbWork(
      tester,
      () => BodyWeightRepository(
        db,
        newTestClock(),
      ).save(LocalDate(2026, 10, 20), 80),
    );
    await openStats(tester);
    await tester.tap(find.text(S.statsTabOverall));
    await settle(tester);
    expect(find.text(S.strengthIndex), findsOneWidget);
    expect(find.text(S.strengthIndexSubtitle(1)), findsOneWidget);
    // Streak right after the index, highlighted (1.0.1).
    expect(find.text(S.streakTitle), findsOneWidget);
    expect(
      find.text('2 ${S.streakWeeksLabel(2)}', findRichText: true),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text(S.streakTitle)).dy,
      greaterThan(tester.getTopLeft(find.text(S.strengthIndex)).dy),
    );
    // Body weight chart without a switch (1.0.1).
    await tester.dragUntilVisible(
      find.text(S.average7),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    expect(find.text(S.average7), findsOneWidget);

    await tester.dragUntilVisible(
      find.text(S.calendar),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text(S.setsPerCategory),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    expect(find.text(S.category(null)), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('records tab: best values; tap opens the exercise', (
    tester,
  ) async {
    await seed(tester);
    await openStats(tester);
    await tester.tap(find.text(S.statsTabRecords));
    await settle(tester);
    expect(
      find.text('${S.recordKind(RecordKind.weight)}: 65 kg · 30.10.'),
      findsOneWidget,
    );
    expect(
      find.text('${S.recordKind(RecordKind.duration)}: 1:00 min · 30.10.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Plank'));
    await settle(tester);
    expect(find.text(S.metric(ExerciseMetric.maxDuration)), findsWidgets);
    await disposeApp(tester, db);
  });

  group('info icons (M9)', () {
    Future<void> expectInfo(
      WidgetTester tester,
      String title,
      String textPart,
    ) async {
      await tester.tap(find.byTooltip('${S.explain}: $title').first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AlertDialog, title), findsOneWidget);
      expect(find.textContaining(textPart), findsOneWidget);
      await tester.tap(find.text(S.ok));
      await tester.pumpAndSettle();
    }

    testWidgets('exercise metric: explanation follows the chosen metric', (
      tester,
    ) async {
      await seed(tester);
      await openStats(tester);
      await openExerciseTab(tester);
      await expectInfo(
        tester,
        S.metric(ExerciseMetric.estimatedOneRepMax),
        'Epley',
      );
      await tester.tap(find.text(S.metric(ExerciseMetric.volume)));
      await tester.pumpAndSettle();
      await expectInfo(
        tester,
        S.metric(ExerciseMetric.volume),
        'Summe aus Gewicht × Wdh',
      );
      await disposeApp(tester, db);
    });

    testWidgets('overall and records tab', (tester) async {
      await seed(tester);
      await openStats(tester);
      await tester.tap(find.text(S.statsTabOverall));
      await settle(tester);
      await expectInfo(tester, S.strengthIndex, 'Fortschritt der Übungen');
      await tester.dragUntilVisible(
        find.text(S.trainingVolume),
        find.byType(ListView).last,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await expectInfo(tester, S.trainingVolume, 'ein Balken je');
      await tester.tap(find.text(S.statsTabRecords));
      await settle(tester);
      await expectInfo(tester, S.statsTabRecords, 'Startwert');
      await disposeApp(tester, db);
    });
  });
}
