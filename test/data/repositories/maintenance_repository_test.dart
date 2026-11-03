import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/demo/demo_data.dart';
import 'package:gymlog/data/demo/dev_tools.dart';
import 'package:gymlog/data/repositories/exercise_repository.dart';
import 'package:gymlog/data/repositories/maintenance_repository.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late MaintenanceRepository repo;
  late SettingsRepository settings;

  setUp(() {
    db = newTestDatabase();
    repo = MaintenanceRepository(db);
    settings = SettingsRepository(db);
  });
  tearDown(() => db.close());

  test('replaceAll inserts the demo dataset with all ids', () async {
    final data = generateDemoData(now: testNow);
    await repo.replaceAll(data);
    final counts = await repo.counts();
    expect(counts.exercises, data.exercises.length);
    expect(counts.plans, 2);
    expect(counts.sessions, data.sessions.length);
    expect(counts.sets, data.sets.length);
    expect(counts.bodyWeights, data.bodyWeights.length);
    expect(await db.sessionsDao.getActive(), isNull);
    final squat = data.exercises.firstWhere((e) => e.name == 'Kniebeuge');
    expect(await db.exercisesDao.findById(squat.id), squat);
  });

  test('replaceAll removes previous data but keeps settings', () async {
    await ExerciseRepository(
      db,
      newTestClock(),
    ).create(const ExerciseDraft(name: 'Alt', type: ExerciseType.weightReps));
    await settings.update(
      (s) => s.copyWith(defaultRestSec: 120, themeMode: ThemePreference.dark),
    );
    await repo.replaceAll(generateDemoData(now: testNow));
    final names = (await db.exercisesDao.getAll()).map((e) => e.name);
    expect(names, isNot(contains('Alt')));
    final s = await settings.get();
    expect((s.defaultRestSec, s.themeMode), (120, ThemePreference.dark));
  });

  test('a failing replaceAll rolls back completely', () async {
    await repo.replaceAll(generateDemoData(now: testNow));
    final before = await repo.counts();
    final broken = Dataset(
      exercises: [
        Exercise(
          id: 1,
          name: 'X',
          type: ExerciseType.weightReps,
          category: null,
          incrementKg: 2.5,
          restSec: null,
          includeInStrengthIndex: true,
          notes: '',
          archived: false,
          createdAt: testNow,
        ),
      ],
      // References a plan that does not exist → foreign key violation.
      planExercises: const [
        PlanExercise(
          id: 1,
          planId: 99,
          exerciseId: 1,
          position: 0,
          targetSets: 3,
          targetReps: null,
          targetDurationSec: null,
          restSec: null,
        ),
      ],
    );
    await expectLater(repo.replaceAll(broken), throwsA(anything));
    final after = await repo.counts();
    expect(
      (after.exercises, after.sessions, after.sets, after.bodyWeights),
      (before.exercises, before.sessions, before.sets, before.bodyWeights),
    );
  });

  test(
    'replaceAll rejects non-normalized times before touching data',
    () async {
      final local = Dataset(
        sessions: [
          Session(
            id: 1,
            planId: null,
            planNameSnapshot: null,
            startedAt: DateTime(2026, 11, 3, 18),
            endedAt: null,
            notes: '',
          ),
        ],
      );
      expect(() => repo.replaceAll(local), throwsArgumentError);
    },
  );

  test('wipeAll deletes everything and resets the settings', () async {
    await repo.replaceAll(generateDemoData(now: testNow));
    await settings.update((s) => s.copyWith(lastSelectedPlanId: 1));
    await repo.wipeAll();
    expect((await repo.counts()).isEmpty, isTrue);
    expect(await settings.get(), AppSettings.defaults);
  });

  test('dev tools refuse to run outside the DEV app', () async {
    final tools = DevTools(repo, newTestClock(), enabled: false);
    await expectLater(tools.generateDemoData(), throwsStateError);
    await expectLater(tools.deleteAllData(), throwsStateError);
  });

  test('dev tools generate demo data and delete all data', () async {
    final tools = DevTools(repo, newTestClock(), enabled: true);
    final counts = await tools.generateDemoData();
    expect(counts.sessions, greaterThan(0));
    await tools.deleteAllData();
    expect((await repo.counts()).isEmpty, isTrue);
  });
}
