/// Values of a set being entered or edited (not yet stored).
final class SetValues {
  const SetValues({this.weightKg, this.reps, this.durationSec});

  final double? weightKg;
  final int? reps;
  final int? durationSec;

  SetValues copyWith({
    Object? weightKg = _unset,
    Object? reps = _unset,
    Object? durationSec = _unset,
  }) => SetValues(
    weightKg: identical(weightKg, _unset) ? this.weightKg : weightKg as double?,
    reps: identical(reps, _unset) ? this.reps : reps as int?,
    durationSec: identical(durationSec, _unset)
        ? this.durationSec
        : durationSec as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is SetValues &&
      other.weightKg == weightKg &&
      other.reps == reps &&
      other.durationSec == durationSec;

  @override
  int get hashCode => Object.hash(weightKg, reps, durationSec);

  @override
  String toString() => 'SetValues($weightKg kg, $reps, ${durationSec}s)';
}

const Object _unset = Object();
