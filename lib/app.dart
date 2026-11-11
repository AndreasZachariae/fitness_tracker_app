import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/strings_de.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'domain/models/enums.dart';
import 'features/heart_rate/heart_rate_recorder.dart';
import 'features/notifications/reminder_sync.dart';

/// German (Germany) is the only supported locale.
const appUiLocale = Locale('de', 'DE');

class GymLogApp extends ConsumerWidget {
  const GymLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference =
        ref.watch(settingsProvider).value?.themeMode ?? ThemePreference.system;
    return MaterialApp.router(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (preference) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
      locale: appUiLocale,
      supportedLocales: const [appUiLocale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      // Reminders and the update check (1.2.0).
      builder: (context, child) =>
          ReminderSync(child: HeartRateRecorder(child: child!)),
    );
  }
}
