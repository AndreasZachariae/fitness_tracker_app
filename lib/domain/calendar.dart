import 'models/local_date.dart';

/// An ISO week (Monday to Sunday, SPEC §4).
final class IsoWeek implements Comparable<IsoWeek> {
  const IsoWeek(this.year, this.week);

  /// The ISO week containing [day].
  factory IsoWeek.of(LocalDate day) {
    // The Thursday of the same week decides the year (ISO 8601).
    final thursday = day.addDays(4 - day.weekday);
    final jan1 = LocalDate(thursday.year, 1, 1);
    return IsoWeek(thursday.year, thursday.differenceInDays(jan1) ~/ 7 + 1);
  }

  final int year;
  final int week;

  @override
  int compareTo(IsoWeek other) => year != other.year
      ? year.compareTo(other.year)
      : week.compareTo(other.week);

  @override
  bool operator ==(Object other) =>
      other is IsoWeek && other.year == year && other.week == week;

  @override
  int get hashCode => Object.hash(year, week);

  @override
  String toString() => '$year-W${week.toString().padLeft(2, '0')}';
}

/// Monday of the week containing [day].
LocalDate mondayOf(LocalDate day) => day.addDays(1 - day.weekday);

/// Whole weeks from the week of [from] to the week of [to].
int weeksBetween(LocalDate from, LocalDate to) =>
    mondayOf(to).differenceInDays(mondayOf(from)) ~/ 7;
