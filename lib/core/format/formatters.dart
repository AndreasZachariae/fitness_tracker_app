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

/// Running time: `42:13` below one hour, `1:05:00` from one hour on.
String formatElapsed(Duration duration) =>
    duration.inHours >= 1 ? formatHms(duration) : formatMinSec(duration);

/// Short date without year: `3.11.`
String formatShortDate(DateTime time) =>
    DateFormat('d.M.', appLocale).format(time.toLocal());

/// Training duration: `52 min`, `1:05 h`.
String formatTrainingDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60}:${_two(minutes % 60)} h';
}

/// Parses a duration typed by the user: seconds (`90`) or `m:ss` (`1:30`).
/// Returns `null` for empty, invalid or non-positive input.
int? parseDurationInput(String input) {
  final text = input.trim();
  final match = RegExp(r'^(\d+):([0-5]\d)$').firstMatch(text);
  final seconds = match != null
      ? int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!)
      : int.tryParse(text);
  return seconds != null && seconds > 0 ? seconds : null;
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

/// Weekday and short date: `Di, 3.11.`
String formatWeekdayDate(DateTime time) =>
    '${DateFormat.E(appLocale).format(time.toLocal())}, '
    '${formatShortDate(time)}';

/// Full date: `Di, 3.11.2026`
String formatWeekdayDateYear(DateTime time) =>
    '${DateFormat.E(appLocale).format(time.toLocal())}, '
    '${DateFormat('d.M.yyyy', appLocale).format(time.toLocal())}';

/// Clock time: `18:20`
String formatClockTime(DateTime time) =>
    DateFormat.Hm(appLocale).format(time.toLocal());

/// Month heading: `November 2026`
String formatMonth(DateTime time) =>
    DateFormat('MMMM yyyy', appLocale).format(time.toLocal());

final NumberFormat _oneDecimal = NumberFormat('#,##0.0', appLocale);

/// Body weight with one decimal: `81,5 kg`.
/// "+3 %", "−12 %" (1.3.1: summary and history).
String formatPercentChange(double change) =>
    '${change >= 0 ? '+' : '−'}'
    '${NumberFormat.decimalPattern(appLocale).format(change.abs().round())} %';

String formatKg1(double kg) => '${_oneDecimal.format(kg)} kg';

/// Number with one decimal without unit: `81,5`.
String formatDecimal1(double value) => _oneDecimal.format(value);

/// Signed change with one decimal: `+0,4 kg`, `−1,2 kg`, `±0,0 kg`.
String formatSignedKg1(double kg) {
  final rounded = (kg * 10).round() / 10;
  final sign = rounded > 0 ? '+' : (rounded < 0 ? '−' : '±');
  return '$sign${_oneDecimal.format(rounded.abs())} kg';
}

/// Date with year: `3.11.2026`
String formatDateLong(DateTime time) =>
    DateFormat('d.M.yyyy', appLocale).format(time.toLocal());

/// Date and time: `3.11.2026, 18:20`
String formatDateTime(DateTime time) =>
    '${formatDateLong(time)}, ${formatClockTime(time)}';

/// Minutes after midnight as `18:00` (1.2.0).
String formatMinuteOfDay(int minute) =>
    '${_two(minute ~/ 60)}:${_two(minute % 60)}';
