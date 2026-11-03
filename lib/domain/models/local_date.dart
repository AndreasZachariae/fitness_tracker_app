/// A calendar day without time and time zone, e.g. for body weight entries.
///
/// Stored as `YYYY-MM-DD`. Derive it from a point in time with
/// [LocalDate.fromDateTime], which uses the local time of the device.
final class LocalDate implements Comparable<LocalDate> {
  LocalDate(this.year, this.month, this.day) {
    final normalized = DateTime.utc(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw ArgumentError('Invalid date: $year-$month-$day');
    }
  }

  /// The local calendar day of [time] (UTC values are converted to local).
  factory LocalDate.fromDateTime(DateTime time) {
    final local = time.toLocal();
    return LocalDate(local.year, local.month, local.day);
  }

  /// Parses `YYYY-MM-DD`. Throws a [FormatException] otherwise.
  factory LocalDate.parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) throw FormatException('Expected YYYY-MM-DD', value);
    try {
      return LocalDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    } on ArgumentError {
      throw FormatException('Invalid date', value);
    }
  }

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  /// Weekday, 1 = Monday … 7 = Sunday.
  int get weekday => _utcMidnight.weekday;

  DateTime get _utcMidnight => DateTime.utc(year, month, day);

  /// Start of this day in local time.
  DateTime toLocalDateTime() => DateTime(year, month, day);

  LocalDate addDays(int days) {
    final d = _utcMidnight.add(Duration(days: days));
    return LocalDate(d.year, d.month, d.day);
  }

  /// Whole days from [other] to this date (positive if this is later).
  int differenceInDays(LocalDate other) =>
      _utcMidnight.difference(other._utcMidnight).inDays;

  bool isBefore(LocalDate other) => compareTo(other) < 0;

  bool isAfter(LocalDate other) => compareTo(other) > 0;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  /// `YYYY-MM-DD`
  String toIsoString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIsoString();
}
