import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/build_info.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/router.dart';
import '../../data/providers.dart';
import 'data/backup_hint.dart';
import 'dev_tools_section.dart';

/// Settings, shown above the tab shell (SPEC §6.7). Since 1.2.1 a start
/// page: one entry per area, each with its own page.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.showDevTools = isDevBuild});

  /// Dev-only section; `false` in the release app.
  final bool showDevTools;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(knownUpdateProvider);

    Widget entry(
      IconData icon,
      String title,
      String subtitle,
      String route, {
      bool highlight = false,
    }) => _SettingsEntry(
      icon: icon,
      title: title,
      subtitle: subtitle,
      highlight: highlight,
      onTap: () => context.push(route),
    );

    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          // A due backup shows right here (1.2.1), too.
          const BackupHint(),
          entry(
            Icons.fitness_center,
            S.settingsExercises,
            S.settingsExercisesSubtitle,
            AppRoutes.exercises,
          ),
          entry(
            Icons.list_alt_outlined,
            S.settingsPlans,
            S.settingsPlansSubtitle,
            AppRoutes.plans,
          ),
          entry(
            Icons.timer_outlined,
            S.sectionTraining,
            S.settingsTrainingSubtitle,
            AppRoutes.trainingSettings,
          ),
          entry(
            Icons.notifications_outlined,
            S.sectionNotifications,
            S.settingsNotificationsSubtitle,
            AppRoutes.notificationSettings,
          ),
          entry(
            Icons.event_available_outlined,
            S.sectionBooking,
            S.settingsBookingSubtitle,
            AppRoutes.bookingSettings,
          ),
          entry(
            Icons.palette_outlined,
            S.sectionAppearance,
            S.settingsAppearanceSubtitle,
            AppRoutes.appearanceSettings,
          ),
          entry(
            Icons.save_outlined,
            S.sectionData,
            S.settingsDataSubtitle,
            AppRoutes.dataSettings,
          ),
          entry(
            Icons.info_outline,
            S.sectionAbout,
            update != null
                ? S.updateAvailable(update)
                : S.settingsAboutSubtitle,
            AppRoutes.about,
            highlight: update != null,
          ),
          if (showDevTools) const DevToolsSection(),
        ],
      ),
    );
  }
}

/// One area of the settings: icon in a tinted circle, title, short
/// description (1.2.1).
class _SettingsEntry extends StatelessWidget {
  const _SettingsEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Badge(
        // Blue dot: something new here (an update, 1.2.2).
        isLabelVisible: highlight,
        smallSize: 10,
        backgroundColor: scheme.primary,
        child: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          child: Icon(icon),
        ),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        subtitle,
        style: highlight
            ? TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)
            : null,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
