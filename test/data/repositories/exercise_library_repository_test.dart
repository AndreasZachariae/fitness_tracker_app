import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/exercise_repository.dart';
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
}
