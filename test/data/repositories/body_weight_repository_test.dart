import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/body_weight_repository.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late BodyWeightRepository repo;
  final today = LocalDate.fromDateTime(testNow);

  setUp(() {
    db = newTestDatabase();
    repo = BodyWeightRepository(db, newTestClock());
  });
  tearDown(() => db.close());

  test('save inserts, saving the same day overwrites', () async {
    final first = await repo.save(today, 81.46);
    expect(first.weightKg, 81.5, reason: 'rounded to one decimal');
    final second = await repo.save(today, 80.9);
    expect(second.id, first.id);
    expect(second.createdAt, first.createdAt);
    final all = await repo.watchAll().first;
    expect(all.single.weightKg, 80.9);
  });

  test('entries are listed newest first', () async {
    await repo.save(today.addDays(-2), 82);
    await repo.save(today, 81);
    await repo.save(today.addDays(-1), 81.5);
    expect((await repo.watchAll().first).map((e) => e.date), [
      today,
      today.addDays(-1),
      today.addDays(-2),
    ]);
  });

  test('future days and implausible weights are rejected', () async {
    await expectLater(
      repo.save(today.addDays(1), 80),
      throwsA(isA<InvalidValueException>()),
    );
    for (final kg in [0.0, 19.9, 400.1, double.nan]) {
      await expectLater(
        repo.save(today, kg),
        throwsA(isA<InvalidValueException>()),
        reason: '$kg',
      );
    }
  });

  test('delete', () async {
    final e = await repo.save(today, 80);
    await repo.delete(e.id);
    expect(await repo.findByDate(today), isNull);
    await expectLater(repo.delete(e.id), throwsA(isA<NotFoundException>()));
  });

  test('restore puts a deleted entry back with its id', () async {
    final e = await repo.save(today, 80.4);
    await repo.delete(e.id);
    await repo.restore(e);
    expect(await repo.findByDate(today), e);
    await expectLater(repo.restore(e), throwsA(isA<InvalidValueException>()));
  });

  test('1.7.0: scale values – saved, kept when left out, checked', () async {
    const scale = (musclePct: 41.24, fatPct: 18.5, waterPct: 55.0, boneKg: 3.4);
    final saved = await repo.save(today, 80, composition: scale);
    expect(saved.musclePct, 41.2, reason: 'rounded');
    // Weight only (e.g. edited in the list): the values stay.
    final kept = await repo.save(today, 79.5);
    expect(kept.composition, (
      musclePct: 41.2,
      fatPct: 18.5,
      waterPct: 55.0,
      boneKg: 3.4,
    ));
    expect((await repo.watchAll().first).single.fatPct, 18.5);
    // Given explicitly: replaced, empty ones removed.
    final replaced = await repo.save(
      today,
      79.5,
      composition: (
        musclePct: null,
        fatPct: 19.0,
        waterPct: null,
        boneKg: null,
      ),
    );
    expect(
      (replaced.musclePct, replaced.fatPct, replaced.boneKg),
      (null, 19.0, null),
    );
    for (final bad in [
      (musclePct: 0.5, fatPct: null, waterPct: null, boneKg: null),
      (musclePct: null, fatPct: 100.0, waterPct: null, boneKg: null),
      (musclePct: null, fatPct: null, waterPct: null, boneKg: 25.0),
    ]) {
      await expectLater(
        repo.save(today, 80, composition: bad),
        throwsA(isA<InvalidValueException>()),
      );
    }
  });
}
