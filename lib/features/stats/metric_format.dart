import 'package:intl/intl.dart';

import '../../core/format/exercise_format.dart';
import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../domain/statistics.dart';

final _int = NumberFormat.decimalPattern(appLocale);

/// A metric value with unit: `82,5 kg`, `12 Wdh`, `1:30 min`, `4.320 kg`.
/// With [levels] (levels without kg, 1.1.0) weights are levels: `Stufe 12`.
String formatMetric(
  ExerciseMetric metric,
  double value, {
  bool levels = false,
}) => switch (metric) {
  ExerciseMetric.estimatedOneRepMax ||
  ExerciseMetric.maxWeight ||
  ExerciseMetric.effectiveOneRepMax when levels =>
    '${S.level} ${formatDecimal1((value * 10).round() / 10)}',
  ExerciseMetric.volume when levels =>
    '${_int.format(value.round())} ${S.levelReps}',
  ExerciseMetric.estimatedOneRepMax ||
  ExerciseMetric.maxWeight ||
  ExerciseMetric.effectiveOneRepMax => formatKg((value * 10).round() / 10),
  ExerciseMetric.maxAddedWeight => formatSignedKg((value * 10).round() / 10),
  ExerciseMetric.volume => '${_int.format(value.round())} ${S.unitKg}',
  ExerciseMetric.maxReps ||
  ExerciseMetric.totalReps => '${value.round()} ${S.repsUnit}',
  ExerciseMetric.maxDuration ||
  ExerciseMetric.totalDuration => formatDuration(value.round()),
};

/// Signed change with percent on its own line: `+5 kg\n(+8 %)`.
///
/// The percentage always wraps as a whole, so long values like
/// `+12,5 kg` never split it (M9).
String formatMetricChange(
  ExerciseMetric metric,
  double change,
  double? pct, {
  bool levels = false,
}) {
  final sign = change > 0 ? '+' : (change < 0 ? '−' : '±');
  final abs = formatMetric(
    metric,
    change.abs(),
    levels: levels,
  ).replaceFirst('+', '');
  // Non-breaking spaces keep "(+8 %)" together.
  final percent = pct == null
      ? ''
      : '\n(${pct >= 0 ? '+' : '−'}${_int.format(pct.abs().round())}\u00A0%)';
  return '$sign$abs$percent';
}

/// Short axis label of a metric value.
String formatAxis(ExerciseMetric metric, double value) => switch (metric) {
  ExerciseMetric.maxDuration || ExerciseMetric.totalDuration => formatMinSec(
    Duration(seconds: value.round()),
  ),
  ExerciseMetric.volume when value >= 1000 =>
    '${NumberFormat('#,##0.#', appLocale).format(value / 1000)}k',
  _ => _int.format(value.round()),
};
