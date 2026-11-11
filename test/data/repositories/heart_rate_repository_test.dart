import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/heart_rate_repository.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/seed.dart';
import '../../helpers/test_db.dart';

/// 1.5.0: heart rate samples go with their training.
void main() {
  late AppDatabase db;
  late Repos r;
  late HeartRateRepository repo;

  setUp(() {
    db = newTestDatabase();
    r = Repos(db);
    repo = HeartRateRepository(db);
  });
  tearDown(() => db.close());

  test('store, read in time order, deleted with the training', () async {
    final bench = await addExercise(r, 'Bankdrücken');
    final session = await r.sessions.start(
      exercises: [SessionExerciseDraft(exerciseId: bench, targetSets: 1)],
    );
    await repo.addSample(
      session,
      testNow.add(const Duration(seconds: 10)),
      130,
    );
    await repo.addSample(session, testNow.add(const Duration(seconds: 5)), 110);
    final samples = await repo.getSamples(session);
    expect(samples.map((s) => s.bpm), [110, 130]);
    expect(samples.first.recordedAt, testNow.add(const Duration(seconds: 5)));
    expect((await repo.watchSamples(session).first).length, 2);

    expect(
      () => repo.addSample(session, testNow, 300),
      throwsA(isA<InvalidValueException>()),
    );

    await r.sessions.delete(session);
    expect(await repo.getSamples(session), isEmpty);
  });
}
