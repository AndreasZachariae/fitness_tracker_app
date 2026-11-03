import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/db/database.dart';
import 'package:gymlog/data/repositories/plan_repository.dart';
import 'package:gymlog/data/repositories/repository_exceptions.dart';
import 'package:gymlog/data/repositories/settings_repository.dart';
import 'package:gymlog/domain/models/models.dart';

import '../../helpers/streams.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;
  late PlanRepository plans;

  setUp(() {
    db = newTestDatabase();
    repo = SettingsRepository(db);
    plans = PlanRepository(db, newTestClock());
  });
  tearDown(() => db.close());

  test('a new database has the default settings', () async {
    expect(await repo.get(), AppSettings.defaults);
  });

  test('update saves and the stream follows', () async {
    final values = await recordStream(
      repo.watch().map((s) => s.themeMode),
      () => repo.update((s) => s.copyWith(themeMode: ThemePreference.dark)),
    );
    expect(values, [ThemePreference.system, ThemePreference.dark]);
  });

  test('lastBackupAt is stored normalized to UTC milliseconds', () async {
    await repo.update(
      (s) => s.copyWith(
        lastBackupAt: DateTime.utc(2026, 11, 3, 17, 20, 0, 123, 456),
      ),
    );
    final at = (await repo.get()).lastBackupAt!;
    expect(at, DateTime.utc(2026, 11, 3, 17, 20, 0, 123));
    expect(at.isUtc, isTrue);
  });

  test('out-of-range values are rejected and nothing changes', () async {
    for (final change in <AppSettings Function(AppSettings)>[
      (s) => s.copyWith(defaultSets: 0),
      (s) => s.copyWith(defaultSets: 11),
      (s) => s.copyWith(defaultRestSec: -1),
      (s) => s.copyWith(backupReminderDays: -1),
    ]) {
      await expectLater(
        repo.update(change),
        throwsA(isA<InvalidValueException>()),
      );
    }
    expect(await repo.get(), AppSettings.defaults);
  });

  test('lastSelectedPlanId must exist and is cleared on plan delete', () async {
    await expectLater(
      repo.update((s) => s.copyWith(lastSelectedPlanId: 5)),
      throwsA(isA<NotFoundException>()),
    );
    final planId = await plans.create('Push');
    await repo.update((s) => s.copyWith(lastSelectedPlanId: planId));
    expect((await repo.get()).lastSelectedPlanId, planId);
    await plans.delete(planId);
    expect((await repo.get()).lastSelectedPlanId, isNull);
  });

  test('a lost settings row is recreated on open', () async {
    await db.customStatement('DELETE FROM app_settings');
    final reopened = AppDatabase(db.executor);
    // beforeOpen of the same connection already ran; call it explicitly.
    await reopened.settingsDao.ensureRow();
    expect(await repo.get(), AppSettings.defaults);
  });
}
