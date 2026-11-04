import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/clock.dart';
import '../domain/history.dart';
import '../domain/models/models.dart';
import '../domain/records.dart';
import '../domain/statistics.dart';
import 'db/database.dart';
import 'demo/dev_tools.dart';
import 'io/data_transfer_service.dart';
import 'io/file_gateway.dart';
import 'repositories/body_weight_repository.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/maintenance_repository.dart';
import 'repositories/plan_repository.dart';
import 'repositories/session_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/stats_repository.dart';

/// The app database. Tests override this with an in-memory database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open(clock: ref.watch(clockProvider));
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

// Live data streams for the UI.

final plansProvider = StreamProvider<List<Plan>>(
  (ref) => ref.watch(planRepositoryProvider).watchPlans(),
);

final planEntriesProvider = StreamProvider.family<List<PlanEntry>, int>(
  (ref, planId) => ref.watch(planRepositoryProvider).watchEntries(planId),
);

/// Supersets and rotations of a plan by id (M9).
final planGroupsProvider = StreamProvider.family<Map<int, PlanGroup>, int>(
  (ref, planId) => ref.watch(planRepositoryProvider).watchGroups(planId),
);

final planEntryCountsProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(planRepositoryProvider).watchEntryCounts(),
);

/// Non-archived exercises, sorted by name.
final activeExercisesProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchActive(),
);

final archivedExercisesProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchArchived(),
);

/// All exercises including archived ones, by id.
final exercisesByIdProvider = StreamProvider<Map<int, Exercise>>(
  (ref) => ref
      .watch(exerciseRepositoryProvider)
      .watchAll()
      .map((list) => {for (final e in list) e.id: e}),
);

final recentExercisesProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchRecentlyUsed(),
);

final lastPerformancesProvider = StreamProvider<Map<int, LastPerformance>>(
  (ref) => ref.watch(sessionRepositoryProvider).watchLastPerformances(),
);

final activeSessionProvider = StreamProvider<Session?>(
  (ref) => ref.watch(sessionRepositoryProvider).watchActive(),
);

final sessionDetailsProvider =
    StreamProvider.family<List<SessionExerciseDetail>, int>(
      (ref, sessionId) =>
          ref.watch(sessionRepositoryProvider).watchDetails(sessionId),
    );

/// Supersets of a session by id (M9).
final sessionSupersetsProvider =
    StreamProvider.family<Map<int, SessionSuperset>, int>(
      (ref, sessionId) =>
          ref.watch(sessionRepositoryProvider).watchSupersets(sessionId),
    );

/// Record sets of a session by set id.
final sessionRecordsProvider =
    StreamProvider.family<Map<int, List<RecordKind>>, int>(
      (ref, sessionId) =>
          ref.watch(sessionRepositoryProvider).watchSessionRecords(sessionId),
    );

final historyProvider = StreamProvider<List<SessionSummary>>(
  (ref) => ref.watch(sessionRepositoryProvider).watchHistory(),
);

final sessionProvider = StreamProvider.family<Session?, int>(
  (ref, id) => ref.watch(sessionRepositoryProvider).watchSession(id),
);

final bodyWeightsProvider = StreamProvider<List<BodyWeightEntry>>(
  (ref) => ref.watch(bodyWeightRepositoryProvider).watchAll(),
);

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(ref.watch(databaseProvider)),
);

/// All data of the statistics tab, updated live.
final statsDataProvider = StreamProvider<StatsData>(
  (ref) => ref.watch(statsRepositoryProvider).watch(),
);

/// Version info of the installed app.
typedef AppInfo = ({String version, String buildNumber});

final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return (version: info.version, buildNumber: info.buildNumber);
});

final fileGatewayProvider = Provider<FileGateway>(
  (ref) => const PlatformFileGateway(),
);

final dataTransferProvider = Provider<DataTransferService>(
  (ref) => DataTransferService(
    db: ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
    files: ref.watch(fileGatewayProvider),
    appVersion: () async {
      final info = await ref.read(appInfoProvider.future);
      return '${info.version}+${info.buildNumber}';
    },
  ),
);
