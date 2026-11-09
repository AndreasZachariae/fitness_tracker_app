import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/settings_section.dart';

/// Settings → Darstellung (1.2.1).
class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final update = settingsUpdater(context, ref);
    return Scaffold(
      appBar: AppBar(title: const Text(S.sectionAppearance)),
      body: settings == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<ThemePreference>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemePreference.system,
                      label: Text(S.themeSystem),
                    ),
                    ButtonSegment(
                      value: ThemePreference.light,
                      label: Text(S.themeLight),
                    ),
                    ButtonSegment(
                      value: ThemePreference.dark,
                      label: Text(S.themeDark),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (v) =>
                      update((s) => s.copyWith(themeMode: v.single)),
                ),
              ],
            ),
    );
  }
}
