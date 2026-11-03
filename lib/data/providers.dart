import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../domain/models/models.dart';
import 'db/database.dart';
import 'demo/dev_tools.dart';
import 'repositories/body_weight_repository.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/maintenance_repository.dart';
import 'repositories/plan_repository.dart';
import 'repositories/session_repository.dart';
import 'repositories/settings_repository.dart';

/// The app database. Tests override this with an in-memory database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) =>
      ExerciseRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final planRepositoryProvider = Provider<PlanRepository>(
  (ref) =>
      PlanRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) =>
      SessionRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final bodyWeightRepositoryProvider = Provider<BodyWeightRepository>(
  (ref) => BodyWeightRepository(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => MaintenanceRepository(ref.watch(databaseProvider)),
);

/// The current settings, updated live.
final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// Demo data and data reset, DEV app only.
final devToolsProvider = Provider<DevTools>(
  (ref) => DevTools(
    ref.watch(maintenanceRepositoryProvider),
    ref.watch(clockProvider),
  ),
);
