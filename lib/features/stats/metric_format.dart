import 'package:intl/intl.dart';

import '../../core/format/exercise_format.dart';
import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../domain/statistics.dart';

final _int = NumberFormat.decimalPattern(appLocale);

/// A metric value with unit: `82,5 kg`, `12 Wdh`, `1:30 min`, `4.320 kg`.
String formatMetric(ExerciseMetric metric, double value) => switch (metric) {
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

/// Signed change with percent: `+5 kg (+8 %)`.
String formatMetricChange(ExerciseMetric metric, double change, double? pct) {
  final sign = change > 0 ? '+' : (change < 0 ? '−' : '±');
  final abs = formatMetric(metric, change.abs()).replaceFirst('+', '');
  final percent = pct == null
      ? ''
      : ' (${pct >= 0 ? '+' : '−'}${_int.format(pct.abs().round())} %)';
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
