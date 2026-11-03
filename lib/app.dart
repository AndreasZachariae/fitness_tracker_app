import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/strings_de.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

/// German (Germany) is the only supported locale.
const appUiLocale = Locale('de', 'DE');

class GymLogApp extends ConsumerWidget {
  const GymLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: appUiLocale,
      supportedLocales: const [appUiLocale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
