/// Weight steps of an exercise (1.1.0): kg steps, lbs plates and numbered
/// levels. Weights are always stored and shown in kg, except for levels
/// without known kg, where the level number is stored.
library;

import 'models/models.dart';

/// Exact kg of one pound.
const kgPerLb = 0.45359237;

/// How [WeightStep.up] / [WeightStep.down] move a weight.
sealed class WeightStep {
  const WeightStep();

  /// The next higher weight.
  double up(double weight);

  /// The next lower weight.
  double down(double weight);
}

/// Fixed steps in kg, e.g. 2.5 kg plates.
final class KgStep extends WeightStep {
  const KgStep(this.kg);

  final double kg;

  @override
  double up(double weight) => _round2(weight + kg);

  @override
  double down(double weight) => _round2(weight - kg);

  @override
  bool operator ==(Object other) => other is KgStep && other.kg == kg;

  @override
  int get hashCode => kg.hashCode;

  @override
  String toString() => 'KgStep($kg)';
}

/// Machines with lbs plates and kg printed next to them: the lbs values are
/// whole multiples of 5, the kg values are rounded to whole kg (e.g. 100 lbs
/// = 45 kg, 115 lbs = 52 kg). A weight is placed on the nearest 5-lbs value,
/// then moved by [lbs]; the result is the printed kg value.
final class LbsStep extends WeightStep {
  const LbsStep(this.lbs);

  final double lbs;

  @override
  double up(double weight) => _move(weight, 1);

  @override
  double down(double weight) => _move(weight, -1);

  double _move(double weight, int direction) {
    if (weight < 0) return -_move(-weight, -direction);
    var plate = lbsPlateOf(weight);
    // Always really move, also when the start was between two plates.
    for (var i = 0; i < 1000; i++) {
      plate += direction * lbs;
      if (plate <= 0) return 0;
      final kg = kgOfLbs(plate);
      if (direction > 0 ? kg > weight : kg < weight) return kg;
    }
    return weight;
  }

  @override
  bool operator ==(Object other) => other is LbsStep && other.lbs == lbs;

  @override
  int get hashCode => lbs.hashCode;

  @override
  String toString() => 'LbsStep($lbs)';
}

/// The lbs plate (multiple of 5) closest to [kg].
double lbsPlateOf(double kg) => (kg / kgPerLb / 5).round() * 5.0;

/// The kg printed next to [lbs]: rounded to whole kg.
double kgOfLbs(double lbs) => (lbs * kgPerLb).roundToDouble();

/// Numbered levels; with [kgPerLevel] the stored weight is level × kg,
/// without it the stored weight is the level number itself.
final class LevelStep extends WeightStep {
  const LevelStep(this.kgPerLevel);

  final double? kgPerLevel;

  /// The level of a stored weight (may be fractional for old kg values).
  double levelOf(double weight) =>
      kgPerLevel == null ? weight : weight / kgPerLevel!;

  /// The stored weight of [level].
  double weightOf(num level) =>
      kgPerLevel == null ? level.toDouble() : _round2(level * kgPerLevel!);

  @override
  double up(double weight) => weightOf(_nearInt(levelOf(weight)).floor() + 1);

  @override
  double down(double weight) {
    final level = _nearInt(levelOf(weight)).ceil() - 1;
    return weightOf(level < 0 ? 0 : level);
  }

  @override
  bool operator ==(Object other) =>
      other is LevelStep && other.kgPerLevel == kgPerLevel;

  @override
  int get hashCode => kgPerLevel.hashCode;

  @override
  String toString() => 'LevelStep($kgPerLevel)';
}

/// The step of [exercise] with the default step of [settings].
WeightStep weightStepOf(Exercise exercise, AppSettings settings) =>
    switch (exercise.stepMode) {
      StepMode.standard => switch (settings.defaultStepUnit) {
        WeightUnit.kg => KgStep(settings.defaultStep),
        WeightUnit.lbs => LbsStep(settings.defaultStep),
      },
      StepMode.kg => KgStep(exercise.incrementKg),
      StepMode.lbs => LbsStep(exercise.incrementLbs),
      StepMode.levels => LevelStep(exercise.levelKg),
    };

/// Levels of [exercise], `null` if it does not use levels.
LevelStep? levelsOf(Exercise exercise) =>
    exercise.stepMode == StepMode.levels ? LevelStep(exercise.levelKg) : null;

/// Whether the stored weights of [exercise] are kg. Not for levels without
/// known kg: those are left out of kg sums like the weekly volume.
bool storesKg(Exercise exercise) =>
    exercise.stepMode != StepMode.levels || exercise.levelKg != null;

double _round2(double value) => (value * 100).round() / 100;

/// Removes floating point noise (8.999999 → 9).
double _nearInt(double value) {
  final r = value.roundToDouble();
  return (value - r).abs() < 1e-6 ? r : value;
}
