import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/notifications/reminder_service.dart';
import 'package:gymlog/data/notifications/update_checker.dart';
import 'package:gymlog/data/repositories/plan_repository.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/reminders.dart';

import '../../helpers/fake_device.dart';
import '../../helpers/test_db.dart';

/// testNow: Tue 3.11.2026, 18:20 local.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeNotifications notifications;
  late PlanRepository plans;
  late SettingsRepository settings;
  late ReminderService service;

  setUp(() {
    db = newTestDatabase();
    clock = newTestClock();
    notifications = FakeNotifications();
    plans = PlanRepository(db, clock);
    settings = SettingsRepository(db);
    service = ReminderService(
      gateway: notifications,
      plans: plans,
      sessions: SessionRepository(db, clock),
      settings: settings,
      clock: clock,
    );
  });
  tearDown(() => db.close());

  group('training days in the repository', () {
    test('set, replace and validate training days; active flag', () async {
      final id = await plans.create('Oberkörper');
      await plans.setSchedule(id, {1: 18 * 60, 4: 18 * 60 + 30});
      var days = await plans.getSchedules(id);
      expect(
        [for (final d in days) (d.weekday, d.minuteOfDay)],
        [(1, 1080), (4, 1110)],
      );
      await plans.setSchedule(id, {5: 7 * 60});
      days = await plans.getSchedules(id);
      expect(days.single.weekday, 5);
      expect(
        () => plans.setSchedule(id, {8: 60}),
        throwsA(isA<InvalidValueException>()),
      );
      expect(
        () => plans.setSchedule(id, {1: 24 * 60}),
        throwsA(isA<InvalidValueException>()),
      );
      await plans.setActive(id, false);
      expect((await plans.findById(id))!.active, isFalse);
      await plans.rename(id, 'Push');
      expect((await plans.findById(id))!.active, isFalse, reason: 'kept');
    });

    test('deleting a plan deletes its training days', () async {
      final id = await plans.create('A');
      await plans.setSchedule(id, {1: 600});
      await plans.delete(id);
      expect(await plans.getAllSchedules(), isEmpty);
    });
  });

  group('sync', () {
    test('plans evening and before reminders with texts and button', () async {
      final id = await plans.create('Oberkörper');
      await plans.setSchedule(id, {DateTime.thursday: 18 * 60 + 30});
      await service.sync();
      final evening = notifications.scheduled.values.firstWhere(
        (n) => n.title == S.notifyEveningTitle('Oberkörper', '18:30'),
      );
      expect(evening.at, DateTime(2026, 11, 4, 20).toUtc());
      expect(evening.body, S.notifyEveningBody);
      expect(evening.buttons.single.id, NotificationPayloads.bookButton);
      final before = notifications.scheduled.values.firstWhere(
        (n) => n.title == S.notifyBeforeTitle(60, 'Oberkörper'),
      );
      expect(S.motivation, contains(before.body));
      expect(before.at, DateTime(2026, 11, 5, 17, 30).toUtc());
    });

    test('a change replaces the planned reminders', () async {
      final id = await plans.create('Oberkörper');
      await plans.setSchedule(id, {DateTime.thursday: 18 * 60});
      await service.sync();
      expect(notifications.scheduled, isNotEmpty);
      await plans.setActive(id, false);
      await service.sync();
      expect(notifications.scheduled, isEmpty);
    });

    test('other notifications stay untouched', () async {
      notifications.scheduled[ReminderIds.update] = (
        id: ReminderIds.update,
        at: null,
        title: 'x',
        body: 'y',
        payload: null,
        buttons: const [],
      );
      await service.sync();
      expect(notifications.scheduled.keys, [ReminderIds.update]);
    });
  });

  group('update check', () {
    late FakeReleases releases;
    late UpdateChecker checker;

    setUp(() {
      releases = FakeReleases('1.3.0');
      checker = UpdateChecker(
        source: releases,
        settings: settings,
        gateway: notifications,
        clock: clock,
        installedVersion: () async => '1.2.0',
      );
    });

    test('a newer version is notified once and remembered', () async {
      await checker.checkIfDue();
      expect(notifications.shown.single.title, S.notifyUpdateTitle('1.3.0'));
      expect(notifications.shown.single.payload, NotificationPayloads.update);
      final s = await settings.get();
      expect((s.latestVersion, s.lastUpdateCheckAt), ('1.3.0', testNow));

      // Within 24 h no request at all.
      clock.advance(const Duration(hours: 23));
      await checker.checkIfDue();
      expect(releases.calls, 1);

      // A day later: same version, no second notification.
      clock.advance(const Duration(hours: 2));
      await checker.checkIfDue();
      expect(releases.calls, 2);
      expect(notifications.shown, hasLength(1));
    });

    test('offline, same version or switched off: no notification', () async {
      releases.version = null;
      await checker.checkIfDue();
      expect((await settings.get()).lastUpdateCheckAt, isNull);
      releases.version = '1.2.0';
      await checker.checkIfDue();
      expect((await settings.get()).latestVersion, isNull);
      await settings.update((s) => s.copyWith(checkUpdates: false));
      clock.advance(const Duration(days: 2));
      releases.version = '2.0.0';
      await checker.checkIfDue();
      expect(notifications.shown, isEmpty);
      expect(releases.calls, 2);
    });
  });

  test('settings: booking address must be https or empty', () async {
    expect(
      () => settings.update((s) => s.copyWith(bookingUrl: 'http://x.de')),
      throwsA(isA<InvalidValueException>()),
    );
    await settings.update((s) => s.copyWith(bookingUrl: ''));
    expect((await settings.get()).bookingUrl, '');
    await settings.update(
      (s) => s.copyWith(bookingUrl: ' https://buchen.example/termin '),
    );
    expect((await settings.get()).bookingUrl, 'https://buchen.example/termin');
  });
}
