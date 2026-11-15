import 'local_date.dart';

/// Body weight of one day (table `body_weight_entries`), since 1.7.0 with
/// the optional values of a smart scale.
final class BodyWeightEntry {
  const BodyWeightEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    required this.createdAt,
    this.musclePct,
    this.fatPct,
    this.waterPct,
    this.boneKg,
  });

  final int id;

  /// Local calendar day; unique.
  final LocalDate date;
  final double weightKg;

  /// UTC.
  final DateTime createdAt;

  /// Muscle mass in % of the body weight (1.7.0).
  final double? musclePct;

  /// Body fat in % (1.7.0).
  final double? fatPct;

  /// Body water in % (1.7.0).
  final double? waterPct;

  /// Bone mass in kg (1.7.0).
  final double? boneKg;

  /// The values of a smart scale of this entry.
  BodyComposition get composition => (
    musclePct: musclePct,
    fatPct: fatPct,
    waterPct: waterPct,
    boneKg: boneKg,
  );

  @override
  bool operator ==(Object other) =>
      other is BodyWeightEntry &&
      other.id == id &&
      other.date == date &&
      other.weightKg == weightKg &&
      other.createdAt == createdAt &&
      other.musclePct == musclePct &&
      other.fatPct == fatPct &&
      other.waterPct == waterPct &&
      other.boneKg == boneKg;

  @override
  int get hashCode => Object.hash(
    id,
    date,
    weightKg,
    createdAt,
    musclePct,
    fatPct,
    waterPct,
    boneKg,
  );

  @override
  String toString() => 'BodyWeightEntry($date, $weightKg kg)';
}

/// The optional values of a smart scale (1.7.0); null = not measured.
typedef BodyComposition = ({
  double? musclePct,
  double? fatPct,
  double? waterPct,
  double? boneKg,
});

/// No value at all.
const BodyComposition noComposition = (
  musclePct: null,
  fatPct: null,
  waterPct: null,
  boneKg: null,
);
