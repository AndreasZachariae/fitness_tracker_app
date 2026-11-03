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
}
