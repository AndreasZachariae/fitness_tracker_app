import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../domain/heart_rate_zones.dart';
import '../../domain/models/models.dart';
import '../../widgets/info_button.dart';
import '../../widgets/settings_section.dart';
import '../heart_rate/zone_colors.dart';

/// Körper → "Puls-Profil" (1.6.0; 1.6.1: zones after the lactate threshold
/// heart rate): zones, warning and pause limit, birth year and sex.
class HeartRateProfileCard extends ConsumerWidget {
  const HeartRateProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).value;
    if (s == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final threshold = s.hrThreshold;
    final now = ref.watch(clockProvider).now();

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: muted)),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );

    return Card.outlined(
      key: const ValueKey('heart-rate-profile'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(S.hrProfile, style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  // The dialog uses its own ref: this card may leave the
                  // screen (and be disposed) while the keyboard is open.
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const HeartRateProfileDialog(),
                  ),
                  child: Text(
                    threshold == null ? S.hrProfileSet : S.hrProfileEdit,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: threshold == null
                  ? Text(S.hrProfileEmpty, style: muted)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        row(S.hrThreshold, '$threshold ${S.unitBpm}'),
                        for (final z in heartRateZones(threshold).reversed)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: zoneColor(z.number),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(S.hrZone(z.number))),
                                Text(
                                  S.hrZoneBpm(z.from, z.to),
                                  style: const TextStyle(
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        row(
                          S.hrWarn,
                          s.hrWarnBpm == null
                              ? S.hrWarnOff
                              : '${s.hrWarnBpm} ${S.unitBpm}',
                        ),
                        row(S.hrPause, '${s.pauseBpm} ${S.unitBpm}'),
                        row(
                          S.hrBirthYear,
                          s.birthYear == null
                              ? '–'
                              : '${s.birthYear} '
                                    '(${S.hrAge(ageAt(s.birthYear!, now))})',
                        ),
                        row(S.hrSex, S.hrSexLabel(s.sex)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The profile form. Warning and pause limit are filled with the
/// suggestions as soon as the threshold is known (and not changed by hand).
class HeartRateProfileDialog extends ConsumerStatefulWidget {
  const HeartRateProfileDialog({super.key});

  @override
  ConsumerState<HeartRateProfileDialog> createState() =>
      _HeartRateProfileDialogState();
}

class _HeartRateProfileDialogState
    extends ConsumerState<HeartRateProfileDialog> {
  late final AppSettings _initial =
      ref.read(settingsProvider).value ?? AppSettings.defaults;
  late final _threshold = TextEditingController(
    text: _initial.hrThreshold?.toString() ?? '',
  );
  late final _birth = TextEditingController(
    text: _initial.birthYear?.toString() ?? '',
  );
  late final _warn = TextEditingController(
    text:
        (_initial.hrWarnBpm ??
                (_initial.hrThreshold == null
                    ? null
                    : defaultWarnBpm(_initial.hrThreshold!)))
            ?.toString() ??
        '',
  );
  late final _pause = TextEditingController(
    text: _initial.pauseBpm?.toString() ?? '',
  );
  late Sex? _sex = _initial.sex;
  bool _tried = false;
  bool _saving = false;

  /// The suggestions last filled in; replaced while not edited by hand.
  late String? _warnSuggested = _warn.text.isEmpty ? null : _warn.text;
  late String? _pauseSuggested = _initial.hrPauseBpm == null
      ? _pause.text
      : null;

  @override
  void dispose() {
    _threshold.dispose();
    _birth.dispose();
    _warn.dispose();
    _pause.dispose();
    super.dispose();
  }

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  bool _empty(TextEditingController c) => c.text.trim().isEmpty;

  void _onThreshold(String _) {
    final t = _int(_threshold);
    if (t != null && t >= 80 && t <= 230) {
      final warn = '${defaultWarnBpm(t)}';
      final pause = '${defaultPauseBpm(t)}';
      if (_empty(_warn) || _warn.text == _warnSuggested) _warn.text = warn;
      if (_empty(_pause) || _pause.text == _pauseSuggested) {
        _pause.text = pause;
      }
      _warnSuggested = warn;
      _pauseSuggested = pause;
    }
    setState(() {});
  }

  String? get _thresholdError {
    final v = _int(_threshold);
    if (_empty(_threshold)) return null;
    return v == null || v < 80 || v > 230 ? S.errorHrThreshold : null;
  }

  String? get _birthError {
    final v = _int(_birth);
    if (_empty(_birth)) return null;
    return v == null || v < 1900 || v > 2100 ? S.errorBirthYear : null;
  }

  String? _bpmError(TextEditingController c, int min, int max) {
    final v = _int(c);
    if (_empty(c)) return null;
    return v == null || v < min || v > max ? S.errorBpm : null;
  }

  bool get _valid =>
      _thresholdError == null &&
      _birthError == null &&
      _bpmError(_warn, 60, 250) == null &&
      _bpmError(_pause, 40, 220) == null;

  Future<void> _save() async {
    setState(() => _tried = true);
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final threshold = _int(_threshold);
    final pause = _int(_pause);
    await settingsUpdater(context, ref)(
      (s) => s.copyWith(
        hrThreshold: threshold,
        birthYear: _int(_birth),
        sex: _sex,
        hrWarnBpm: _int(_warn),
        // The suggestion is not stored: it follows a changed threshold.
        hrPauseBpm: threshold != null && pause == defaultPauseBpm(threshold)
            ? null
            : pause,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    InputDecoration deco(
      String label, {
      String? error,
      Widget? info,
      bool bpm = true,
    }) => InputDecoration(
      labelText: label,
      errorText: _tried ? error : null,
      suffixText: bpm ? S.unitBpm : null,
      suffixIcon: info,
    );
    return AlertDialog(
      title: const Text(S.hrProfile),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('hr-threshold'),
            controller: _threshold,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            decoration: deco(
              S.hrThreshold,
              error: _thresholdError,
              info: const InfoButton(
                title: S.hrThreshold,
                text: S.hrThresholdInfo,
              ),
            ),
            onChanged: _onThreshold,
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('hr-warn'),
            controller: _warn,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            decoration: deco(
              S.hrWarn,
              error: _bpmError(_warn, 60, 250),
              info: InfoButton(
                title: S.hrWarn,
                text: S.hrWarnInfo((warnShare * 100).round()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('hr-pause'),
            controller: _pause,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            decoration: deco(
              S.hrPause,
              error: _bpmError(_pause, 40, 220),
              info: const InfoButton(title: S.hrPause, text: S.hrPauseInfo),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('hr-birth'),
            controller: _birth,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            decoration: deco(S.hrBirthYear, error: _birthError, bpm: false),
          ),
          const SizedBox(height: 12),
          Text(S.hrSex, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          // Optional: no selection = no answer.
          SegmentedButton<Sex>(
            key: const ValueKey('hr-sex'),
            segments: [
              for (final v in Sex.values)
                ButtonSegment(value: v, label: Text(S.hrSexLabel(v))),
            ],
            selected: {?_sex},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            onSelectionChanged: (v) =>
                setState(() => _sex = v.isEmpty ? null : v.first),
          ),
          const SizedBox(height: 8),
          Text(
            S.hrProfileCaloriesHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text(S.save),
        ),
      ],
    );
  }
}
