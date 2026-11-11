import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/app.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/core/device.dart';
import 'package:gymlog/core/heart_rate_monitor.dart';
import 'package:gymlog/core/notifications.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/providers.dart';
import 'package:gymlog/features/notifications/reminder_sync.dart';

import 'fake_device.dart';
import 'fake_files.dart';
import 'test_db.dart';

/// Pumps the whole app on an in-memory database with a fixed clock.
Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  AppDatabase? db,
  Clock? clock,
  FakeFeedback? feedback,
  FakeScreenAwake? screen,
  FakeRestAlarm? alarm,
  FakeFileGateway? files,
  FakeNotifications? notifications,
  FakeReleases? releases,
  FakeHeartRateMonitor? heartRate,
  bool reminderSync = false,
}) async {
  final database = db ?? newTestDatabase();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(clock ?? newTestClock()),
        deviceFeedbackProvider.overrideWithValue(feedback ?? FakeFeedback()),
        screenAwakeProvider.overrideWithValue(screen ?? FakeScreenAwake()),
        restAlarmProvider.overrideWithValue(alarm ?? FakeRestAlarm()),
        notificationGatewayProvider.overrideWithValue(
          notifications ?? FakeNotifications(),
        ),
        releaseSourceProvider.overrideWithValue(releases ?? FakeReleases()),
        heartRateMonitorProvider.overrideWithValue(
          heartRate ?? FakeHeartRateMonitor(),
        ),
        reminderSyncEnabledProvider.overrideWithValue(reminderSync),
        appInfoProvider.overrideWith(
          (ref) async => (version: '0.9.0', buildNumber: '9'),
        ),
        if (files != null) fileGatewayProvider.overrideWithValue(files),
      ],
      child: const GymLogApp(),
    ),
  );
  await tester.pumpAndSettle();
  return database;
}

/// Unmounts the app and closes the database (call at the end of a test).
Future<void> disposeApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await db.close();
}
