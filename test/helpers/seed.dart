import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/exercise_repository.dart';
import 'package:gymlog/data/repositories/plan_repository.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import 'test_db.dart';

/// Repositories on [db] with the fixed test clock.
final class Repos {
  Repos(AppDatabase db)
    : exercises = ExerciseRepository(db, newTestClock()),
      plans = PlanRepository(db, newTestClock()),
      sessions = SessionRepository(db, newTestClock());

  final ExerciseRepository exercises;
  final PlanRepository plans;
  final SessionRepository sessions;
}

/// Runs real database work inside a widget test.
Future<T> dbWork<T>(WidgetTester tester, Future<T> Function() work) async =>
    (await tester.runAsync(work)) as T;

/// Lets pending database streams deliver, then settles the UI.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

Future<int> addExercise(
  Repos r,
  String name, [
  ExerciseType type = ExerciseType.weightReps,
  ExerciseCategory? category,
]) => r.exercises.create(
  ExerciseDraft(name: name, type: type, category: category),
);

/// Closes an open bottom sheet by tapping above it, e.g. the training days
/// sheet that opens after creating a plan (1.2.0).
Future<void> closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(200, 40));
  await settle(tester);
}
