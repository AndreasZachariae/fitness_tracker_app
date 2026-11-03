import 'models/local_date.dart';

/// Display period of charts (SPEC §6.5, §6.6). It only cuts the display;
/// calculations always use the whole history.
enum StatsPeriod {
  fourWeeks,
  threeMonths,
  oneYear,
  all;

  /// First day shown, `null` for everything.
  LocalDate? startFor(LocalDate today) => switch (this) {
    StatsPeriod.fourWeeks => today.addDays(-27),
    StatsPeriod.threeMonths => _monthsBack(today, 3),
    StatsPeriod.oneYear => _monthsBack(today, 12),
    StatsPeriod.all => null,
  };

  bool contains(LocalDate day, LocalDate today) {
    final start = startFor(today);
    return (start == null || !day.isBefore(start)) && !day.isAfter(today);
  }
}

LocalDate _monthsBack(LocalDate d, int months) {
  final total = d.year * 12 + (d.month - 1) - months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return LocalDate(year, month, d.day > lastDay ? lastDay : d.day).addDays(1);
}
