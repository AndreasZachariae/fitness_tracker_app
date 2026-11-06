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

/// Tab "Verlauf" (SPEC §6.4).
void main() {
  late AppDatabase db;
  late Repos r;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
  });

  Future<void> openHistory(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db);
    await settle(tester);
    await tester.tap(find.text(S.tabHistory));
    await settle(tester);
  }

  /// Sessions on 3.11. 18:20 local (Push), 1.11. (free) and 28.10. (Push).
  Future<Map<String, int>> seed(WidgetTester tester) => dbWork(
    tester,
    () async {
      final bench = await addExercise(r, 'Bankdrücken');
      final plank = await addExercise(r, 'Plank', ExerciseType.timed);
      final planId = await r.plans.create('Push');
      final plan = (await r.plans.findById(planId))!;
      final ids = <String, int>{};
      Future<int> at(
        DateTime start,
        Plan? p,
        List<(double, int)> sets, {
        int plankSec = 0,
      }) async {
        final clock = FixedClock(start);
        final repo = SessionRepository(db, clock);
        final id = await repo.start(
          plan: p,
          exercises: [
            SessionExerciseDraft(exerciseId: bench, targetSets: 3),
            SessionExerciseDraft(exerciseId: plank, targetSets: 1),
          ],
        );
        final d = await repo.getDetails(id);
        for (final (kg, reps) in sets) {
          clock.advance(const Duration(minutes: 3));
          await repo.addSet(d[0].sessionExercise.id, weightKg: kg, reps: reps);
        }
        if (plankSec > 0) {
          await repo.addSet(d[1].sessionExercise.id, durationSec: plankSec);
        }
        clock.time = start.add(const Duration(minutes: 52));
        await repo.finishSession(id);
        return id;
      }

      ids['oct'] = await at(DateTime.utc(2026, 10, 28, 17), plan, [(60, 10)]);
      ids['free'] = await at(DateTime.utc(2026, 11, 1, 9), null, [(60, 8)]);
      ids['nov'] = await at(DateTime.utc(2026, 11, 3, 16, 20), plan, [
        (62.5, 10),
        (62.5, 10),
      ], plankSec: 60);
      return ids;
    },
  );

  testWidgets('empty state', (tester) async {
    await openHistory(tester);
    expect(find.text(S.historyEmpty), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('grouped by month with key figures and record mark', (
    tester,
  ) async {
    await seed(tester);
    await openHistory(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(find.text('Di, 3.11. · Push'), findsOneWidget);
    expect(find.text('So, 1.11. · ${S.freeTrainingTitle}'), findsOneWidget);
    expect(find.text('52 min · 3 Sätze · 1.250 kg'), findsOneWidget);
    // Only the 3.11. session beat earlier sets.
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    // Newest first.
    final nov = tester.getTopLeft(find.text('Di, 3.11. · Push')).dy;
    final oct = tester.getTopLeft(find.text('Mi, 28.10. · Push')).dy;
    expect(nov, lessThan(oct));
    await disposeApp(tester, db);
  });

  testWidgets('detail: times, notes, sets, edit a set, record label', (
    tester,
  ) async {
    final ids = await seed(tester);
    await openHistory(tester);
    await tester.tap(find.text('Di, 3.11. · Push'));
    await settle(tester);

    expect(find.text('Di, 3.11.2026'), findsOneWidget);
    expect(find.text('17:20 – 18:12 · 52 min'), findsOneWidget);
    expect(find.text('62,5 kg × 10'), findsNWidgets(2));
    expect(find.text('1:00 min'), findsOneWidget);
    expect(find.text(S.record), findsOneWidget);

    await tester.tap(find.text('62,5 kg × 10').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('${S.reps}: ${S.decrease}'));
    await tester.tap(find.widgetWithText(TextButton, S.save));
    await settle(tester);
    expect(find.text('62,5 kg × 9'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Schulter gut');
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(
      (await dbWork(tester, () => r.sessions.findById(ids['nov']!)))!.notes,
      'Schulter gut',
    );
    await disposeApp(tester, db);
  });

  testWidgets('remove an exercise from the session', (tester) async {
    final ids = await seed(tester);
    await openHistory(tester);
    await tester.tap(find.text('Di, 3.11. · Push'));
    await settle(tester);
    await tester.tap(find.byTooltip(S.moreActions).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.removeFromSession));
    await tester.pumpAndSettle();
    expect(find.text(S.removeFromSessionTitle('Plank')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, S.remove));
    await settle(tester);
    final d = await dbWork(tester, () => r.sessions.getDetails(ids['nov']!));
    expect(d.single.exercise.name, 'Bankdrücken');
    expect(find.text('1:00 min'), findsNothing);
    await disposeApp(tester, db);
  });

  testWidgets('delete asks with date and plan name', (tester) async {
    final ids = await seed(tester);
    await openHistory(tester);
    await tester.tap(find.text('Di, 3.11. · Push'));
    await settle(tester);
    await tester.tap(find.byTooltip(S.deleteSession));
    await tester.pumpAndSettle();
    expect(
      find.text(S.deleteSessionTitle('Di, 3.11.', 'Push')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, S.cancel));
    await tester.pumpAndSettle();
    expect(
      await dbWork(tester, () => r.sessions.findById(ids['nov']!)),
      isNotNull,
    );

    await tester.tap(find.byTooltip(S.deleteSession));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, S.delete));
    await settle(tester);
    expect(
      await dbWork(tester, () => r.sessions.findById(ids['nov']!)),
      isNull,
    );
    expect(find.text(S.sessionDeleted), findsOneWidget);
    expect(find.text('Di, 3.11. · Push'), findsNothing);
    expect(find.text('So, 1.11. · ${S.freeTrainingTitle}'), findsOneWidget);

    // "Rückgängig" brings the training back with all sets (1.0.1).
    final before = await dbWork(tester, () => r.sessions.watchHistory().first);
    await tester.tap(find.text(S.undo));
    await settle(tester);
    expect(find.text('Di, 3.11. · Push'), findsOneWidget);
    final restored = await dbWork(
      tester,
      () => r.sessions.getDetails(ids['nov']!),
    );
    expect(restored.expand((d) => d.sets), isNotEmpty);
    expect(
      await dbWork(tester, () => r.sessions.watchHistory().first),
      hasLength(before.length + 1),
    );
    await disposeApp(tester, db);
  });

  testWidgets('times dialog rejects an end before the start', (tester) async {
    await seed(tester);
    await openHistory(tester);
    await tester.tap(find.text('Di, 3.11. · Push'));
    await settle(tester);
    await tester.tap(find.text('17:20 – 18:12 · 52 min'));
    await tester.pumpAndSettle();
    expect(find.text(S.editTimes), findsOneWidget);
    expect(find.text(S.errorEndBeforeStart), findsNothing);
    // Saving unchanged times works.
    await tester.tap(find.widgetWithText(TextButton, S.save));
    await settle(tester);
    expect(find.text('17:20 – 18:12 · 52 min'), findsOneWidget);
    await disposeApp(tester, db);
  });
}
