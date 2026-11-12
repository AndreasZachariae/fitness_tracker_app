import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../domain/heart_rate_ranges.dart';
import '../../domain/models/models.dart';
import '../../widgets/info_button.dart';
import '../../widgets/settings_section.dart';
import '../heart_rate/range_colors.dart';

/// Körper → "Puls-Profil" (1.6.0): maximum heart rate with Garmin's ranges,
/// birth year and sex (calories), warning and pause limit.
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
    final hrMax = s.hrMax;
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
                const InfoButton(title: S.hrMax, text: S.hrMaxInfo),
                TextButton(
                  onPressed: () => showHeartRateProfileDialog(context, ref, s),
                  child: Text(hrMax == null ? S.hrProfileSet : S.hrProfileEdit),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: hrMax == null
                  ? Text(S.hrProfileEmpty, style: muted)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        row(S.hrMax, '$hrMax ${S.unitBpm}'),
                        for (final r in garminRanges(hrMax).reversed)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: rangeColor(r.number),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(S.hrRange(r.number))),
                                Text(
                                  S.hrRangeBpm(r.from, r.to),
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
                              : S.hrWarnAbove(s.hrWarnBpm!),
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

/// The profile form.
Future<void> showHeartRateProfileDialog(
  BuildContext context,
  WidgetRef ref,
  AppSettings s,
) => showDialog<void>(
  context: context,
  builder: (_) => _ProfileDialog(initial: s, ref: ref),
);

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.initial, required this.ref});

  final AppSettings initial;
  final WidgetRef ref;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final _max = TextEditingController(
    text: widget.initial.hrMax?.toString() ?? '',
  );
  late final _birth = TextEditingController(
    text: widget.initial.birthYear?.toString() ?? '',
  );
  late final _warn = TextEditingController(
    text: widget.initial.hrWarnBpm?.toString() ?? '',
  );
  late final _pause = TextEditingController(
    text: widget.initial.hrPauseBpm?.toString() ?? '',
  );
  late Sex? _sex = widget.initial.sex;
  bool _tried = false;

  @override
  void dispose() {
    _max.dispose();
    _birth.dispose();
    _warn.dispose();
    _pause.dispose();
    super.dispose();
  }

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  bool _empty(TextEditingController c) => c.text.trim().isEmpty;

  String? get _maxError {
    final v = _int(_max);
    if (_empty(_max)) return null;
    return v == null || v < 100 || v > 250 ? S.errorHrMax : null;
  }

  String? get _birthError {
    final v = _int(_birth);
    if (_empty(_birth)) return null;
    return v == null || v < 1900 || v > 2100 ? S.errorBirthYear : null;
  }

  String? _bpmError(TextEditingController c, int min) {
    final v = _int(c);
    if (_empty(c)) return null;
    return v == null || v < min || v > 250 ? S.errorBpm : null;
  }

  bool get _valid =>
      _maxError == null &&
      _birthError == null &&
      _bpmError(_warn, 60) == null &&
      _bpmError(_pause, 40) == null;

  Future<void> _save() async {
    setState(() => _tried = true);
    if (!_valid) return;
    await settingsUpdater(context, widget.ref)(
      (s) => s.copyWith(
        hrMax: _int(_max),
        birthYear: _int(_birth),
        sex: _sex,
        hrWarnBpm: _int(_warn),
        hrPauseBpm: _int(_pause),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final max = _int(_max);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    InputDecoration deco(String label, {String? hint, String? error}) =>
        InputDecoration(
          labelText: label,
          helperText: hint,
          helperMaxLines: 2,
          errorText: _tried ? error : null,
          suffixText: label == S.hrBirthYear ? null : S.unitBpm,
        );
    return AlertDialog(
      title: const Text(S.hrProfile),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('hr-max'),
            controller: _max,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            decoration: deco(S.hrMax, error: _maxError),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('hr-warn'),
            controller: _warn,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            decoration: deco(
              S.hrWarn,
              hint: max == null || max < 100
                  ? null
                  : S.hrWarnHint(defaultWarnBpm(max)),
              error: _bpmError(_warn, 60),
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
              hint: max == null || max < 100
                  ? null
                  : S.hrPauseHint(defaultPauseBpm(max)),
              error: _bpmError(_pause, 40),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('hr-birth'),
            controller: _birth,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            decoration: deco(S.hrBirthYear, error: _birthError),
          ),
          const SizedBox(height: 12),
          Text(S.hrSex, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SegmentedButton<Sex?>(
            segments: [
              for (final v in [null, Sex.male, Sex.female])
                ButtonSegment(value: v, label: Text(S.hrSexLabel(v))),
            ],
            selected: {_sex},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _sex = v.first),
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
        FilledButton(onPressed: _save, child: const Text(S.save)),
      ],
    );
  }
}
