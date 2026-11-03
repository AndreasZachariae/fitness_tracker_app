import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:gymlog/core/clock.dart';
import 'package:gymlog/data/db/database.dart';

/// 2026-11-03 18:20 local (Berlin), a Tuesday.
final testNow = DateTime.utc(2026, 11, 3, 17, 20);

/// A fresh in-memory database with the full schema.
AppDatabase newTestDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

FixedClock newTestClock() => FixedClock(testNow);
