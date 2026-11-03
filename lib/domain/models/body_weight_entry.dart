import 'local_date.dart';

/// Body weight of one day (table `body_weight_entries`).
final class BodyWeightEntry {
  const BodyWeightEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    required this.createdAt,
  });

  final int id;

  /// Local calendar day; unique.
  final LocalDate date;
  final double weightKg;

  /// UTC.
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is BodyWeightEntry &&
      other.id == id &&
      other.date == date &&
      other.weightKg == weightKg &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, date, weightKg, createdAt);

  @override
  String toString() => 'BodyWeightEntry($date, $weightKg kg)';
}
