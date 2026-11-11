import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/core/heart_rate_monitor.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/heart_rate_repository.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import '../helpers/fake_device.dart';
import '../helpers/pump_app.dart';
import '../helpers/seed.dart';
import '../helpers/test_db.dart';

/// 1.5.0: Bluetooth heart rate monitor.
void main() {
  late AppDatabase db;
  late Repos r;
  late FixedClock clock;
  late FakeHeartRateMonitor monitor;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
    clock = newTestClock();
    monitor = FakeHeartRateMonitor();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db: db, clock: clock, heartRate: monitor);
    await settle(tester);
  }

  Future<void> openPage(WidgetTester tester) async {
    await tester.tap(find.byTooltip(S.openSettings));
    await settle(tester);
    await tester.tap(find.text(S.sectionHeartRate));
    await settle(tester);
  }

  Future<AppSettings> settings(WidgetTester tester) =>
      dbWork(tester, () => SettingsRepository(db).get());

  testWidgets('settings: find, keep, test and remove a monitor', (
    tester,
  ) async {
    monitor
      ..state = HeartRateAvailability.noPermission
      ..devices.addAll([(id: 'AA:01', name: 'Forerunner 255')]);
    await open(tester);
    await tester.tap(find.byTooltip(S.openSettings));
    await settle(tester);
    expect(find.text(S.settingsHeartRateNone), findsOneWidget);
    await tester.tap(find.text(S.sectionHeartRate));
    await settle(tester);
    expect(find.text(S.heartRateGarminHint), findsOneWidget);

    // Asks for the permission, then finds the watch (the spinner keeps
    // turning, so no settle).
    await tester.tap(find.text(S.heartRateSearch).last);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(monitor.permissionRequests, 1);
    expect(find.text('Forerunner 255'), findsOneWidget);
    await tester.tap(find.text('Forerunner 255'));
    await settle(tester);
    final saved = await settings(tester);
    expect((saved.hrDeviceId, saved.hrDeviceName), ('AA:01', 'Forerunner 255'));
    expect(find.text(S.heartRateDevice), findsOneWidget);

    // Try it out.
    await tester.tap(find.text(S.heartRateTest));
    await settle(tester);
    expect(find.text(S.heartRateConnecting), findsOneWidget);
    monitor.beat(92);
    await tester.pump();
    await tester.pump();
    expect(find.text(S.heartRateNow(92)), findsOneWidget);
    monitor.lose();
    await tester.pump();
    await tester.pump();
    expect(find.text(S.heartRateLost), findsOneWidget);
    await tester.tap(find.text(S.heartRateStopTest));
    await settle(tester);

    await tester.tap(find.text(S.heartRateRemove));
    await settle(tester);
    expect((await settings(tester)).hrDeviceId, isNull);
    expect(find.text(S.heartRateDevice), findsNothing);
    await disposeApp(tester, db);
  });

  testWidgets('settings: explains an old Android and Bluetooth off', (
    tester,
  ) async {
    monitor.state = HeartRateAvailability.unsupported;
    await open(tester);
    await openPage(tester);
    await tester.tap(find.text(S.heartRateSearch).last);
    await settle(tester);
    expect(find.text(S.heartRateUnsupported), findsOneWidget);

    monitor.state = HeartRateAvailability.bluetoothOff;
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.text(S.heartRateSearch).last);
    await settle(tester);
    expect(find.text(S.heartRateBluetoothOff), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('training: connects, shows and stores the heart rate, '
      'reconnects, disconnects at the end; curve in the history', (
    tester,
  ) async {
    final session = await dbWork(tester, () async {
      await SettingsRepository(db).update(
        (s) => s.copyWith(hrDeviceId: 'AA:01', hrDeviceName: 'Forerunner 255'),
      );
      final bench = await addExercise(r, 'Bankdrücken');
      return SessionRepository(db, clock).start(
        exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 3)],
      );
    });
    await open(tester);
    expect(monitor.connects, ['AA:01']);
    final indicator = find.byKey(const ValueKey('heart-rate-indicator'));
    expect(
      find.descendant(of: indicator, matching: find.text('–')),
      findsOneWidget,
    );

    monitor.beat(128);
    await tester.pump();
    await tester.pump();
    expect(
      find.descendant(of: indicator, matching: find.text('128')),
      findsOneWidget,
    );

    // Stored at once, then at most every 5 seconds.
    clock.advance(const Duration(seconds: 2));
    monitor.beat(130);
    await tester.pump();
    clock.advance(const Duration(seconds: 4));
    monitor.beat(150);
    await tester.pump();
    await settle(tester);
    final samples = await dbWork(
      tester,
      () => HeartRateRepository(db).getSamples(session),
    );
    expect(samples.map((s) => s.bpm), [128, 150]);

    // Lost: "–", then a new attempt after 5 seconds.
    monitor.lose();
    await tester.pump();
    await tester.pump();
    expect(
      find.descendant(of: indicator, matching: find.text('–')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(monitor.connects, ['AA:01', 'AA:01']);
    expect(monitor.connected, isTrue);

    // The training ends: disconnected.
    await dbWork(
      tester,
      () => SessionRepository(db, clock).finishSession(session),
    );
    await settle(tester);
    expect(monitor.connected, isFalse);
    expect(indicator, findsNothing);

    // The history shows average, maximum and the curve.
    await tester.tap(find.text(S.tabHistory));
    await settle(tester);
    await tester.tap(find.textContaining('Di, 3.11.'));
    await settle(tester);
    expect(find.text(S.heartRateSummary(139, 150)), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('no monitor chosen: nothing connects, no indicator', (
    tester,
  ) async {
    await dbWork(tester, () async {
      final bench = await addExercise(r, 'Bankdrücken');
      await SessionRepository(db, clock).start(
        exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 3)],
      );
    });
    await open(tester);
    expect(monitor.connects, isEmpty);
    expect(find.byKey(const ValueKey('heart-rate-indicator')), findsNothing);
    await disposeApp(tester, db);
  });
}
