import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/reminders.dart';

import '../helpers/fake_device.dart';
import '../helpers/pump_app.dart';
import '../helpers/seed.dart';
import '../helpers/test_db.dart';

/// 1.2.0: training days, notification settings, reminder sync, updates.
void main() {
  late AppDatabase db;
  late Repos r;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await settle(tester);
  }

  testWidgets('a new plan offers its training days; inactive is greyed', (
    tester,
  ) async {
    phone(tester);
    await pumpApp(tester, db: db);
    await tester.tap(find.text(S.addPlanChip));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Push');
    await tester.tap(find.text(S.create));
    await settle(tester);

    expect(find.textContaining(S.planScheduleTitle), findsOneWidget);
    await tester.tap(find.text(S.weekdays[0]));
    await settle(tester);
    await tester.tap(find.text(S.weekdays[3]));
    await settle(tester);
    expect(find.text('18:00'), findsNWidgets(2));
    final plan = (await dbWork(tester, r.plans.getPlans)).single;
    expect(
      [
        for (final d in await dbWork(
          tester,
          () => r.plans.getSchedules(plan.id),
        ))
          (d.weekday, d.minuteOfDay),
      ],
      [(1, 1080), (4, 1080)],
    );

    await tester.tap(find.text(S.planActive));
    await settle(tester);
    expect((await dbWork(tester, r.plans.getPlans)).single.active, isFalse);
    await tester.tapAt(const Offset(200, 60));
    await settle(tester);

    // Long press menu offers the training days again.
    await tester.longPress(find.widgetWithText(ChoiceChip, 'Push'));
    await tester.pumpAndSettle();
    expect(find.text(S.planSchedule), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('settings: notification switches, booking page, update hint', (
    tester,
  ) async {
    phone(tester);
    await dbWork(
      tester,
      () =>
          SettingsRepository(db)
              .update((s) => s.copyWith(latestVersion: '1.3.0')),
    );
    await pumpApp(tester, db: db);
    await tester.tap(find.byTooltip(S.openSettings));
    await settle(tester);

    await tester.dragUntilVisible(
      find.text(S.settingNotifyStreak),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tapVisible(tester, find.text(S.settingNotifyStreak));
    expect(
      (await dbWork(tester, SettingsRepository(db).get)).notifyStreak,
      isFalse,
    );

    final url = find.widgetWithText(TextField, S.settingBookingUrl);
    await tester.ensureVisible(url);
    await tester.enterText(url, 'http://unsicher.de');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text(S.errorBookingUrl), findsOneWidget);
    expect(
      (await dbWork(tester, SettingsRepository(db).get)).bookingUrl,
      AppSettings.defaultBookingUrl,
    );
    await tester.enterText(url, 'https://buchen.example/termin');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(
      (await dbWork(tester, SettingsRepository(db).get)).bookingUrl,
      'https://buchen.example/termin',
    );

    // Installed is 0.9.0 in tests.
    await tester.dragUntilVisible(
      find.text(S.updateAvailable('1.3.0')),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text(S.updateDownload), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('reminder sync: asks once, plans reminders, checks updates', (
    tester,
  ) async {
    phone(tester);
    await dbWork(tester, () async {
      final id = await r.plans.create('Beine');
      await r.plans.setSchedule(id, {DateTime.friday: 17 * 60});
    });
    final notifications = FakeNotifications();
    final releases = FakeReleases('1.0.0');
    await pumpApp(
      tester,
      db: db,
      notifications: notifications,
      releases: releases,
      reminderSync: true,
    );
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(notifications.permissionRequests, 1);
    expect(
      (await dbWork(tester, SettingsRepository(db).get)).notificationsAsked,
      isTrue,
    );
    expect(
      notifications.scheduled.values.map((n) => n.title),
      contains(S.notifyEveningTitle('Beine', '17:00')),
    );
    expect(notifications.shown.single.id, ReminderIds.update);

    // A new training day is planned right away.
    await dbWork(tester, () async {
      final id = (await r.plans.getPlans()).single.id;
      await r.plans.setSchedule(id, {DateTime.saturday: 10 * 60});
    });
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(
      notifications.scheduled.values.map((n) => n.title),
      isNot(contains(S.notifyEveningTitle('Beine', '17:00'))),
    );
    expect(
      notifications.scheduled.values.map((n) => n.title),
      contains(S.notifyEveningTitle('Beine', '10:00')),
    );
    await disposeApp(tester, db);
  });
}
