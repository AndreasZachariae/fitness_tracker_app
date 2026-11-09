import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/body/body_page.dart';
import '../features/history/history_page.dart';
import '../features/history/session_detail_page.dart';
import '../features/settings/about_page.dart';
import '../features/settings/appearance_settings_page.dart';
import '../features/settings/booking_settings_page.dart';
import '../features/settings/data/data_settings_page.dart';
import '../features/settings/exercises/exercise_archive_page.dart';
import '../features/settings/exercises/exercise_list_page.dart';
import '../features/settings/notification_settings.dart';
import '../features/settings/plans/plan_list_page.dart';
import '../features/settings/plans/plan_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/training_settings_page.dart';
import '../features/stats/stats_page.dart';
import '../features/training/summary/summary_page.dart';
import '../features/training/training_page.dart';
import '../widgets/home_shell.dart';

/// Route paths of the app.
abstract final class AppRoutes {
  static const training = '/training';
  static const history = '/history';
  static String historyDetail(int sessionId) => '/history/$sessionId';
  static const stats = '/stats';
  static const body = '/body';

  /// Settings live above the shell (no navigation bar).
  static const settings = '/settings';
  static const exercises = '/settings/exercises';
  static const exerciseArchive = '/settings/exercises/archive';
  static const plans = '/settings/plans';
  static const trainingSettings = '/settings/training';
  static const notificationSettings = '/settings/notifications';
  static const bookingSettings = '/settings/booking';
  static const appearanceSettings = '/settings/appearance';
  static const dataSettings = '/settings/data';
  static const about = '/settings/about';

  /// One plan: name, active, training days, duplicate, delete (1.2.1).
  static String plan(int planId) => '/plan/$planId';

  /// Full-screen summary after a session (SPEC §6.3).
  static String summary(int sessionId) => '/summary/$sessionId';
}

/// Builds the app router: a [StatefulShellRoute] with one branch per tab and
/// the settings route on the root navigator.
GoRouter createRouter({String initialLocation = AppRoutes.training}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.training,
                builder: (context, state) => const TrainingPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const HistoryPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => SessionDetailPage(
                      sessionId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stats,
                builder: (context, state) => const StatsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.body,
                builder: (context, state) => const BodyPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/summary/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            SummaryPage(sessionId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsPage(),
        routes: [
          GoRoute(
            path: 'exercises',
            builder: (context, state) => const ExerciseListPage(),
            routes: [
              GoRoute(
                path: 'archive',
                builder: (context, state) => const ExerciseArchivePage(),
              ),
            ],
          ),
          GoRoute(
            path: 'plans',
            builder: (context, state) => const PlanListPage(),
          ),
          GoRoute(
            path: 'training',
            builder: (context, state) => const TrainingSettingsPage(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationSettingsPage(),
          ),
          GoRoute(
            path: 'booking',
            builder: (context, state) => const BookingSettingsPage(),
          ),
          GoRoute(
            path: 'appearance',
            builder: (context, state) => const AppearanceSettingsPage(),
          ),
          GoRoute(
            path: 'data',
            builder: (context, state) => const DataSettingsPage(),
          ),
          GoRoute(
            path: 'about',
            builder: (context, state) => const AboutPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/plan/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            PlanPage(planId: int.parse(state.pathParameters['id']!)),
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});
