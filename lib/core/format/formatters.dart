import 'package:intl/intl.dart';

import '../l10n/strings_de.dart';

/// Locale used for all number and date formatting.
const appLocale = 'de_DE';

final NumberFormat _weightFormat = NumberFormat('#,##0.##', appLocale);

/// Formats a weight without unit, e.g. `62,5`, `100`, `1.250`.
String formatWeight(double kg) => _weightFormat.format(kg);

/// Formats a weight with unit, e.g. `62,5 kg`.
String formatKg(double kg) => '${formatWeight(kg)} ${S.unitKg}';

/// Formats a duration as `h:mm:ss`, e.g. `0:42:13`, `1:05:00`.
String formatHms(Duration duration) {
  final total = duration.isNegative ? 0 : duration.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return '$h:${_two(m)}:${_two(s)}';
}

/// Formats a duration as `m:ss`, e.g. `1:12`, `12:05`.
String formatMinSec(Duration duration) {
  final total = duration.isNegative ? 0 : duration.inSeconds;
  return '${total ~/ 60}:${_two(total % 60)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

/// Parses a decimal number typed by the user. Accepts comma and point as
/// decimal separator (`62,5`, `62.5`) and surrounding whitespace.
///
/// Returns `null` for empty or invalid input. Thousands separators are not
/// accepted, so `1.250` is read as 1.25 – weights are entered without them.
double? parseDecimal(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  if (!RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)$').hasMatch(normalized)) return null;
  return double.tryParse(normalized);
}
