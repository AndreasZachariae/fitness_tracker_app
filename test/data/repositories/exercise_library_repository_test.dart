import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/exercise_repository.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/data/repositories/session_repository.dart';
import 'package:gymlog/domain/exercise_library.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/test_db.dart';

void main() {
  group('first start', () {
    test('a new app database starts with the whole library', () async {
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
        libraryClock: newTestClock(),
      );
      final all = await db.exercisesDao.getAll();
      expect(all.length, exerciseLibrary.length);
      expect(all.every((e) => !e.archived), isTrue);
      expect(all.every((e) => e.createdAt == testNow), isTrue);
      final bench = all.firstWhere((e) => e.name == 'Bankdrücken');
      expect(bench.category, ExerciseCategory.chest);
      expect(bench.includeInStrengthIndex, isTrue);
      final plank = all.firstWhere((e) => e.name == 'Plank');
      expect(plank.type, ExerciseType.timed);
      expect(plank.includeInStrengthIndex, isFalse);
      await db.close();
    });

    test('an existing database is never filled up on opening', () async {
      final dir = Directory.systemTemp.createTempSync('gymlog-library');
      final file = File('${dir.path}/gymlog.sqlite');
      try {
        var db = AppDatabase(NativeDatabase(file));
        await ExerciseRepository(db, newTestClock()).create(
          const ExerciseDraft(name: 'Eigene Übung', type: ExerciseType.timed),
        );
        await db.close();

        db = AppDatabase(NativeDatabase(file), libraryClock: newTestClock());
        final names = (await db.exercisesDao.getAll()).map((e) => e.name);
        expect(names, ['Eigene Übung']);
        await db.close();
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('test databases stay empty', () async {
      final db = newTestDatabase();
      expect(await db.exercisesDao.getAll(), isEmpty);
      await db.close();
    });
  });

  group('addLibrary', () {
    late AppDatabase db;
    late ExerciseRepository repo;

    setUp(() {
      db = newTestDatabase();
      repo = ExerciseRepository(db, newTestClock());
    });
    tearDown(() => db.close());

    test('adds only missing exercises and keeps own ones unchanged', () async {
      final ownId = await repo.create(
        const ExerciseDraft(
          name: 'bankdrücken',
          type: ExerciseType.bodyweight,
          category: ExerciseCategory.other,
          notes: 'meine Variante',
        ),
      );
      final archivedId = await repo.create(
        const ExerciseDraft(name: 'Plank', type: ExerciseType.timed),
      );
      final archived = (await repo.findById(archivedId))!;
      await repo.update(archived.copyWith(archived: true));
      final before = await repo.findById(ownId);

      expect(await repo.missingLibraryCount(), exerciseLibrary.length - 2);
      expect(await repo.addLibrary(), exerciseLibrary.length - 2);

      final all = await db.exercisesDao.getAll();
      expect(all.length, exerciseLibrary.length);
      expect(await repo.findById(ownId), before);
      expect((await repo.findById(archivedId))!.archived, isTrue);
      expect(
        all.where((e) => e.name.toLowerCase() == 'bankdrücken'),
        hasLength(1),
      );
    });

    test('a second call adds nothing', () async {
      expect(await repo.addLibrary(), exerciseLibrary.length);
      expect(await repo.missingLibraryCount(), 0);
      expect(await repo.addLibrary(), 0);
      expect((await db.exercisesDao.getAll()).length, exerciseLibrary.length);
    });

    test('added exercises can be used like own ones', () async {
      await repo.addLibrary();
      final squat = (await db.exercisesDao.getAll()).firstWhere(
        (e) => e.name == 'Kniebeugen',
      );
      await repo.update(squat.copyWith(incrementKg: 1.25, notes: 'Stand 3'));
      final changed = (await repo.findById(squat.id))!;
      expect(changed.incrementKg, 1.25);
      expect(await repo.deleteOrArchive(squat.id), ExerciseRemoval.deleted);
      expect(await repo.missingLibraryCount(), 1, reason: 'deleted again');
    });
  });

  group('weight steps when editing (1.1.0)', () {
    late AppDatabase db;
    late ExerciseRepository repo;
    late SessionRepository sessions;

    setUp(() {
      db = newTestDatabase();
      repo = ExerciseRepository(db, newTestClock());
      sessions = SessionRepository(db, newTestClock());
    });
    tearDown(() => db.close());

    Future<int> trained(ExerciseDraft draft, double weight) async {
      final id = await repo.create(draft);
      final s = await sessions.start(
        exercises: [SessionExerciseDraft(exerciseId: id, targetSets: 1)],
      );
      final se = (await sessions.getDetails(s)).single.sessionExercise;
      await sessions.addSet(se.id, weightKg: weight, reps: 10);
      await sessions.finish(s);
      return id;
    }

    Future<double?> weightOf(int exerciseId) async {
      final se = await (db.select(
        db.sessionExercises,
      )..where((x) => x.exerciseId.equals(exerciseId))).getSingle();
      final set = await (db.select(
        db.setEntries,
      )..where((x) => x.sessionExerciseId.equals(se.id))).getSingle();
      return set.weightKg;
    }

    test('create and update keep mode, lbs step and kg per level', () async {
      final id = await repo.create(
        const ExerciseDraft(
          name: 'Seil',
          type: ExerciseType.weightReps,
          stepMode: StepMode.levels,
          levelKg: 4.5,
        ),
      );
      var e = (await repo.findById(id))!;
      expect((e.stepMode, e.levelKg), (StepMode.levels, 4.5));
      await repo.update(e.copyWith(stepMode: StepMode.lbs, incrementLbs: 10));
      e = (await repo.findById(id))!;
      expect((e.stepMode, e.incrementLbs), (StepMode.lbs, 10));
    });

    test('invalid lbs step or kg per level is refused', () async {
      expect(
        () => repo.create(
          const ExerciseDraft(
            name: 'X',
            type: ExerciseType.weightReps,
            levelKg: 0,
          ),
        ),
        throwsA(isA<InvalidValueException>()),
      );
      expect(
        () => repo.create(
          const ExerciseDraft(
            name: 'Y',
            type: ExerciseType.weightReps,
            incrementLbs: -5,
          ),
        ),
        throwsA(isA<InvalidValueException>()),
      );
    });

    test('kg modes among each other: logged kg values stay', () async {
      final id = await trained(
        const ExerciseDraft(name: 'Latzug', type: ExerciseType.weightReps),
        40,
      );
      final e = (await repo.findById(id))!;
      await repo.update(e.copyWith(stepMode: StepMode.levels, levelKg: 4.5));
      expect(await weightOf(id), 40, reason: 'answer of the user: unchanged');
      await repo.update(
        (await repo.findById(id))!.copyWith(stepMode: StepMode.standard),
      );
      expect(await weightOf(id), 40);
    });

    test('levels without kg → with kg converts the level numbers', () async {
      final id = await trained(
        const ExerciseDraft(
          name: 'Seil',
          type: ExerciseType.weightReps,
          stepMode: StepMode.levels,
        ),
        9,
      );
      final e = (await repo.findById(id))!;
      await repo.update(e.copyWith(levelKg: 4.5));
      expect(await weightOf(id), 40.5);
      // And back: kg → level numbers with the old kg per level.
      await repo.update((await repo.findById(id))!.copyWith(levelKg: null));
      expect(await weightOf(id), 9);
    });

    test('level numbers cannot become kg without kg per level', () async {
      final id = await trained(
        const ExerciseDraft(
          name: 'Seil',
          type: ExerciseType.weightReps,
          stepMode: StepMode.levels,
        ),
        9,
      );
      final e = (await repo.findById(id))!;
      expect(
        () => repo.update(e.copyWith(stepMode: StepMode.kg)),
        throwsA(isA<StepChangeNotAllowedException>()),
      );
      final k = await trained(
        const ExerciseDraft(name: 'Bank', type: ExerciseType.weightReps),
        60,
      );
      final bank = (await repo.findById(k))!;
      expect(
        () => repo.update(bank.copyWith(stepMode: StepMode.levels)),
        throwsA(isA<StepChangeNotAllowedException>()),
      );
      expect(await weightOf(id), 9);
    });

    test('without history anything goes', () async {
      final id = await repo.create(
        const ExerciseDraft(
          name: 'Seil',
          type: ExerciseType.weightReps,
          stepMode: StepMode.levels,
        ),
      );
      final e = (await repo.findById(id))!;
      await repo.update(e.copyWith(stepMode: StepMode.kg));
      expect((await repo.findById(id))!.stepMode, StepMode.kg);
    });

    test('the library brings its steps along', () async {
      await repo.addLibrary();
      final all = {for (final e in await db.exercisesDao.getAll()) e.name: e};
      expect(all['Latzug']!.stepMode, StepMode.standard);
      expect(all['Bizepscurls am Kabel']!.levelKg, 4.5);
      expect(all['Bankdrücken']!.stepMode, StepMode.kg);
    });
  });
}
