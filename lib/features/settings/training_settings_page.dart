import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/exercise_format.dart';
import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';
import '../../widgets/number_stepper.dart';
import '../../widgets/settings_section.dart';

/// Settings → Training (1.2.1): defaults and the rest timer.
class TrainingSettingsPage extends ConsumerWidget {
  const TrainingSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final update = settingsUpdater(context, ref);
    return Scaffold(
      appBar: AppBar(title: const Text(S.sectionTraining)),
      body: settings == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                const SettingsSectionHeader(S.sectionDefaults, first: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      NumberStepper(
                        plainLabel: true,
                        label: S.settingDefaultSets,
                        valueText: '${settings.defaultSets}',
                        onDecrement: settings.defaultSets > 1
                            ? () => update(
                                (s) =>
                                    s.copyWith(defaultSets: s.defaultSets - 1),
                              )
                            : null,
                        onIncrement: settings.defaultSets < 10
                            ? () => update(
                                (s) =>
                                    s.copyWith(defaultSets: s.defaultSets + 1),
                              )
                            : null,
                      ),
                      NumberStepper(
                        plainLabel: true,
                        label: S.settingDefaultRest,
                        valueText: formatDuration(settings.defaultRestSec),
                        onDecrement: settings.defaultRestSec >= 15
                            ? () => update(
                                (s) => s.copyWith(
                                  defaultRestSec: s.defaultRestSec - 15,
                                ),
                              )
                            : null,
                        onIncrement: settings.defaultRestSec <= 585
                            ? () => update(
                                (s) => s.copyWith(
                                  defaultRestSec: s.defaultRestSec + 15,
                                ),
                              )
                            : null,
                      ),
                      _DefaultStep(settings: settings, update: update),
                    ],
                  ),
                ),
                const SettingsSectionHeader(S.sectionRestTimer),
                SwitchListTile(
                  title: const Text(S.settingRestTimer),
                  value: settings.restTimerEnabled,
                  onChanged: (v) =>
                      update((s) => s.copyWith(restTimerEnabled: v)),
                ),
                SwitchListTile(
                  title: const Text(S.settingVibration),
                  value: settings.vibrationEnabled,
                  onChanged: (v) =>
                      update((s) => s.copyWith(vibrationEnabled: v)),
                ),
                SwitchListTile(
                  title: const Text(S.settingKeepScreenOn),
                  subtitle: const Text(S.settingKeepScreenOnSubtitle),
                  value: settings.keepScreenOn,
                  onChanged: (v) => update((s) => s.copyWith(keepScreenOn: v)),
                ),
                SwitchListTile(
                  title: const Text(S.settingAutoActivate),
                  value: settings.autoActivateNext,
                  onChanged: (v) =>
                      update((s) => s.copyWith(autoActivateNext: v)),
                ),
              ],
            ),
    );
  }
}

/// "Standard-Steigerung": value and kg/lbs (1.1.0). Steps of 0,5 kg or
/// 5 lbs.
class _DefaultStep extends StatelessWidget {
  const _DefaultStep({required this.settings, required this.update});

  final AppSettings settings;
  final SettingsUpdate update;

  @override
  Widget build(BuildContext context) {
    final unit = settings.defaultStepUnit;
    final (step, min, max) = switch (unit) {
      WeightUnit.kg => (0.5, 0.5, 50.0),
      WeightUnit.lbs => (5.0, 5.0, 100.0),
    };
    final value = settings.defaultStep;
    return NumberStepper(
      plainLabel: true,
      label: S.settingDefaultStep,
      helper: S.settingDefaultStepSubtitle,
      valueText: '${formatWeight(value)} ${S.unit(unit)}',
      onDecrement: value - step >= min - 1e-9
          ? () => update((s) => s.copyWith(defaultStep: value - step))
          : null,
      onIncrement: value + step <= max + 1e-9
          ? () => update((s) => s.copyWith(defaultStep: value + step))
          : null,
      // The unit right below the number it belongs to (1.1.0).
      belowValue: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SegmentedButton<WeightUnit>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final u in WeightUnit.values)
              ButtonSegment(value: u, label: Text(S.unit(u))),
          ],
          selected: {unit},
          // The number stays, only the unit changes (within its limits).
          onSelectionChanged: (v) => update((s) {
            final u = v.single;
            final limit = u == WeightUnit.kg ? 50.0 : 100.0;
            return s.copyWith(
              defaultStepUnit: u,
              defaultStep: s.defaultStep > limit ? limit : s.defaultStep,
            );
          }),
        ),
      ),
    );
  }
}
