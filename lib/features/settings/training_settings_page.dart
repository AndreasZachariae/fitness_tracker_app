import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device.dart';
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
                // 1.6.3: strength instead of on/off; 0 = off.
                _VibrationStrength(
                  strength: settings.vibrationStrength,
                  update: update,
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
                // 1.7.0: a second view for a phone in a device mount.
                const SettingsSectionHeader(S.sectionTrainingLayout),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: SegmentedButton<TrainingLayout>(
                    key: const ValueKey('training-layout'),
                    segments: [
                      for (final l in TrainingLayout.values)
                        ButtonSegment(
                          value: l,
                          label: Text(S.trainingLayout(l)),
                        ),
                    ],
                    selected: {settings.trainingLayout},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) =>
                        update((s) => s.copyWith(trainingLayout: v.first)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    S.trainingLayoutHint(settings.trainingLayout),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }
}

/// "Standard-Steigerung": value and kg/lbs (1.1.0). Steps of 0,5 kg or
/// 5 lbs.
/// "Vibration" as a slider in steps of 10 % (1.6.3): 0 = off; on release
/// one short test pulse in the chosen strength.
class _VibrationStrength extends ConsumerStatefulWidget {
  const _VibrationStrength({required this.strength, required this.update});

  final int strength;
  final SettingsUpdate update;

  @override
  ConsumerState<_VibrationStrength> createState() => _VibrationStrengthState();
}

class _VibrationStrengthState extends ConsumerState<_VibrationStrength> {
  /// The value while dragging; null = the stored one.
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = (_dragging ?? widget.strength.toDouble()).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  S.settingVibration,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Text(
                S.vibrationStrength(value),
                key: const ValueKey('vibration-strength-value'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('vibration-strength'),
            value: value.toDouble(),
            max: 100,
            divisions: 10,
            label: S.vibrationStrength(value),
            onChanged: (v) => setState(() => _dragging = v),
            onChangeEnd: (v) async {
              final strength = v.round();
              setState(() => _dragging = null);
              await widget.update(
                (s) => s.copyWith(vibrationStrength: strength),
              );
              if (strength > 0) {
                await ref.read(deviceFeedbackProvider).testPulse(strength);
              }
            },
          ),
        ],
      ),
    );
  }
}

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
