import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/l10n/strings_de.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/notifications/apk_downloader.dart';
import 'package:gymlog/data/notifications/reminder_service.dart';
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

  testWidgets('a new plan opens its page: days and "Aktiv" separately '
      '(1.2.1)', (tester) async {
    phone(tester);
    await pumpApp(tester, db: db);
    await tester.tap(find.text(S.addPlanChip));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Push');
    await tester.tap(find.text(S.create));
    await settle(tester);

    expect(find.text(S.planSchedule), findsOneWidget, reason: 'plan page');
    expect(find.text(S.planActive), findsOneWidget);
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
    await leavePage(tester);

    // A long press on the chip opens the same page.
    await tester.longPress(find.widgetWithText(ChoiceChip, 'Push'));
    await settle(tester);
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
    // Installed is 0.9.0 in tests: "Über" on the start page shows it.
    await tester.dragUntilVisible(
      find.text(S.updateAvailable('1.3.0')),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text(S.updateAvailable('1.3.0')), findsOneWidget);
    await tester.dragUntilVisible(
      find.text(S.sectionNotifications),
      find.byType(ListView),
      const Offset(0, 300),
    );

    await tester.tap(find.text(S.sectionNotifications));
    await settle(tester);
    // Plain label like the switches, no "(einziger Internetzugriff)".
    expect(find.textContaining('Internetzugriff'), findsNothing);
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

    await leavePage(tester);
    await tester.tap(find.text(S.sectionBooking));
    await settle(tester);
    expect(find.text(S.bookingInfo), findsOneWidget);
    final url = find.widgetWithText(TextField, S.settingBookingUrl);
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
    // 1.6.1: the button next to it saves and opens the page in the browser.
    final openButton = find.byKey(const ValueKey('booking-url-open'));
    await tester.enterText(url, 'https://buchen.example/neu');
    await tester.pump();
    await tester.tap(openButton);
    await settle(tester);
    expect(
      (await dbWork(tester, SettingsRepository(db).get)).bookingUrl,
      'https://buchen.example/neu',
    );
    await tester.enterText(url, '');
    await tester.pump();
    expect(tester.widget<IconButton>(openButton).onPressed, isNull);
    await tester.enterText(url, 'https://buchen.example/neu');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    await leavePage(tester);
    await tester.ensureVisible(find.text(S.sectionAbout));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.sectionAbout));
    await settle(tester);
    expect(find.text(S.updateAvailable('1.3.0')), findsOneWidget);
    expect(find.text(S.updateOpen), findsOneWidget);
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
    // Looked just now: a fresh start of the app still looks (1.2.2).
    await dbWork(
      tester,
      () =>
          SettingsRepository(db)
              .update((s) => s.copyWith(lastUpdateCheckAt: testNow)),
    );
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
    // A new version: notification and blue dot, no page of its own (1.3.1).
    expect(find.text(S.updateHeadline('DEV 1.0.0')), findsNothing);
    final dot = find.byKey(const ValueKey('settings-update-dot'));
    expect(tester.widget<Badge>(dot.first).isLabelVisible, isTrue);

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

  testWidgets('Über: "Nach Updates suchen" on demand (1.2.1)', (tester) async {
    phone(tester);
    final releases = FakeReleases();
    await pumpApp(tester, db: db, releases: releases);
    await tester.tap(find.byTooltip(S.openSettings));
    await settle(tester);
    await tester.dragUntilVisible(
      find.text(S.sectionAbout),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(find.text(S.sectionAbout));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.sectionAbout));
    await settle(tester);
    expect(find.text(S.checkForUpdatesHint), findsOneWidget);

    // Offline.
    await tester.tap(find.text(S.checkForUpdates));
    await settle(tester);
    expect(find.text(S.updateCheckFailed), findsOneWidget);

    // Same version as installed (0.9.0 in tests).
    releases.version = '0.9.0';
    await tester.tap(find.text(S.checkForUpdates));
    await settle(tester);
    expect(find.text(S.upToDate('0.9.0')), findsOneWidget);
    expect(find.text(S.updateOpen), findsNothing);

    // Newer: hint and the button to the update page.
    releases.version = '1.3.0';
    await tester.tap(find.text(S.checkForUpdates));
    await settle(tester);
    expect(find.text(S.updateAvailable('1.3.0')), findsOneWidget);
    expect(find.text(S.updateOpen), findsOneWidget);
    expect(releases.calls, 3, reason: 'each tap looks, no time limit');
    expect(
      (await dbWork(tester, SettingsRepository(db).get)).latestVersion,
      '1.3.0',
    );

    // The notes of the newest release fold open (1.2.2).
    expect(find.text('Etwas Neues'), findsNothing);
    await tester.tap(find.text(S.releaseNotesLatestDev));
    await settle(tester);
    expect(find.text('Etwas Neues'), findsOneWidget);
    expect(releases.calls, 3, reason: 'already loaded');
    await disposeApp(tester, db);
  });

  testWidgets('update page: APK download, GitHub, no installing; '
      'blue dots (1.2.2)', (tester) async {
    phone(tester);
    final releases = FakeReleases('1.3.0');
    await pumpApp(tester, db: db, releases: releases);
    final dot = find.byKey(const ValueKey('settings-update-dot'));
    expect(tester.widget<Badge>(dot.first).isLabelVisible, isFalse);

    await tester.tap(find.byTooltip(S.openSettings));
    await settle(tester);
    await tester.dragUntilVisible(
      find.text(S.sectionAbout),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(find.text(S.sectionAbout));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.sectionAbout));
    await settle(tester);
    await tester.tap(find.text(S.checkForUpdates));
    await settle(tester);
    await tester.tap(find.text(S.updateOpen));
    await settle(tester);

    expect(find.text(S.updateHeadline('DEV 1.3.0')), findsOneWidget);
    expect(find.text(S.updateInstalled('0.9.0')), findsOneWidget);
    expect(find.text(S.updateDownload), findsOneWidget);
    expect(find.text(S.updateOnGitHub), findsOneWidget);
    expect(find.text(S.updateDownloadHint), findsOneWidget);
    expect(find.text(S.releaseNotesDev), findsOneWidget);
    expect(find.text('Etwas Neues'), findsOneWidget, reason: 'open at once');
    expect(releases.calls, 1, reason: 'the page uses the known result');

    // A release without APK only offers GitHub.
    releases.apkUrl = null;
    await leavePage(tester);
    await tester.tap(find.text(S.checkForUpdates));
    await settle(tester);
    await tester.tap(find.text(S.updateOpen));
    await settle(tester);
    expect(find.text(S.updateNoApk), findsOneWidget);
    expect(find.text(S.updateDownload), findsNothing);
    expect(find.text(S.updateOnGitHub), findsOneWidget);

    // The known update shows as a blue dot on "Über" and on the gear.
    await leavePage(tester);
    await leavePage(tester);
    await tester.dragUntilVisible(
      find.text(S.updateAvailable('1.3.0')),
      find.byType(ListView),
      const Offset(0, -300),
    );
    final aboutDot = find.ancestor(
      of: find.byIcon(Icons.info_outline),
      matching: find.byType(Badge),
    );
    expect(tester.widget<Badge>(aboutDot).isLabelVisible, isTrue);
    await leavePage(tester);
    expect(tester.widget<Badge>(dot.first).isLabelVisible, isTrue);
    await disposeApp(tester, db);
  });

  testWidgets('update page: download with progress, then install by hand '
      '(1.6.1)', (tester) async {
    phone(tester);
    final releases = FakeReleases('1.3.0')
      ..apkUrl = 'https://github.com/x/y/releases/download/v1.3.0/gymlog.apk'
      ..apkAssetUrl = 'https://api.github.com/repos/x/y/releases/assets/7';
    final downloader = FakeApkDownloader();
    await pumpApp(tester, db: db, releases: releases, downloader: downloader);
    await tester.tap(find.byTooltip(S.openSettings));
    await settle(tester);
    await tester.dragUntilVisible(
      find.text(S.sectionAbout),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(find.text(S.sectionAbout));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.sectionAbout));
    await settle(tester);
    await tester.tap(find.text(S.checkForUpdates));
    await settle(tester);
    await tester.tap(find.text(S.updateOpen));
    await settle(tester);

    // Failing: retry, or the browser as before.
    downloader.fail = true;
    await tester.tap(find.text(S.updateDownload));
    await tester.pump();
    expect(find.text(S.updateDownloadFailed), findsOneWidget);
    expect(find.text(S.updateDownloadInBrowser), findsOneWidget);

    downloader
      ..fail = false
      ..state = (
        status: ApkDownloadStatus.running,
        received: 12 * 1024 * 1024,
        total: 24 * 1024 * 1024,
        file: null,
        found: null,
      );
    await tester.tap(find.text(S.updateRetry).last);
    await tester.pump();
    await tester.pump();
    // 1.6.2: the asset address (new for every upload) and the version in
    // the name, so a newer APK is downloaded anew and checked.
    expect(downloader.started, [
      '${releases.apkAssetUrl} → gymlog-1.3.0.apk (1.3.0)',
    ]);
    expect(find.text(S.updateProgress('12,0', '24,0')), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.5);

    downloader.state = (
      status: ApkDownloadStatus.done,
      received: 24 * 1024 * 1024,
      total: 24 * 1024 * 1024,
      file: 'gymlog.apk',
      found: null,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(S.updateDownloaded('gymlog.apk')), findsOneWidget);
    expect(find.text(S.updateInstallHint), findsOneWidget);
    await tester.tap(find.text(S.updateOpenFolder));
    await tester.pump();
    expect(downloader.opened, 1);
    // 1.6.2: the hint suffices, no extra settings button.
    expect(find.text(S.updateInstallHint), findsOneWidget);
    // Polling ends with the download.
    await tester.pump(const Duration(seconds: 2));

    // 1.6.2: GitHub still delivered the previous version: removed, retry
    // looks on GitHub again.
    await leavePage(tester);
    await tester.tap(find.text(S.updateOpen));
    await settle(tester);
    downloader.state = (
      status: ApkDownloadStatus.stale,
      received: 24 * 1024 * 1024,
      total: 24 * 1024 * 1024,
      file: null,
      found: '1.2.9',
    );
    await tester.tap(find.text(S.updateDownload));
    await tester.pump();
    await tester.pump();
    expect(find.text(S.updateDownloadStale('1.2.9')), findsOneWidget);
    final calls = releases.calls;
    await tester.tap(find.text(S.updateRetry));
    await settle(tester);
    expect(releases.calls, calls + 1);
    expect(find.text(S.updateDownload), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('a new version only notifies; the notification leads to its '
      'page (1.3.1)', (tester) async {
    phone(tester);
    final notifications = FakeNotifications();
    await pumpApp(
      tester,
      db: db,
      notifications: notifications,
      releases: FakeReleases('1.3.0'),
      reminderSync: true,
    );
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(notifications.shown.single.id, ReminderIds.update);
    expect(find.text(S.updateHeadline('DEV 1.3.0')), findsNothing);

    // The notification leads there.
    notifications.onTap!(NotificationPayloads.update, null);
    await settle(tester);
    expect(find.text(S.updateHeadline('DEV 1.3.0')), findsOneWidget);
    await disposeApp(tester, db);
  });
}
