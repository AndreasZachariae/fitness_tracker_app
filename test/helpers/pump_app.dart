import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/app.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/providers.dart';

import 'test_db.dart';

/// Pumps the whole app on an in-memory database with a fixed clock.
Future<AppDatabase> pumpApp(WidgetTester tester, {AppDatabase? db}) async {
  final database = db ?? newTestDatabase();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(newTestClock()),
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
