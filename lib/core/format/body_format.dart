import '../../domain/body_weight.dart';
import '../../domain/models/models.dart';
import '../l10n/strings_de.dart';
import 'formatters.dart';

/// Unit of a body value (1.7.0): `kg` or `%`.
String bodyMetricUnit(BodyMetric metric) => switch (metric) {
  BodyMetric.weight || BodyMetric.bone => S.unitKg,
  BodyMetric.fat || BodyMetric.muscle || BodyMetric.water => S.unitPercent,
};

/// `81,5 kg`, `18,4 %`.
String formatBodyValue(BodyMetric metric, double value) =>
    '${formatDecimal1(value)} ${bodyMetricUnit(metric)}';

/// `+0,4 kg`, `−1,2 %`, `±0,0 %`.
String formatBodyChange(BodyMetric metric, double change) {
  final rounded = (change * 10).round() / 10;
  final sign = rounded > 0 ? '+' : (rounded < 0 ? '−' : '±');
  return '$sign${formatDecimal1(rounded.abs())} ${bodyMetricUnit(metric)}';
}

/// The scale values of an entry in one line: `Fett 18,4 % · Muskeln 41,0 %`;
/// empty without any.
String formatComposition(BodyWeightEntry e) => [
  for (final m in BodyMetric.values)
    if (m != BodyMetric.weight)
      if (bodyMetricValue(m, e) case final v?)
        '${S.bodyMetricShort(m)} ${formatBodyValue(m, v)}',
].join(' · ');
