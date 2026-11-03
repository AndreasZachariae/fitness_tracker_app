/// Targets of an exercise in a plan or session list.
final class ExerciseTargets {
  const ExerciseTargets({
    required this.sets,
    this.reps,
    this.durationSec,
    this.restSec,
  });

  final int sets;
  final int? reps;
  final int? durationSec;

  /// Rest override; `null` = rest of the exercise or the default.
  final int? restSec;

  ExerciseTargets copyWith({
    int? sets,
    Object? reps = _unset,
    Object? durationSec = _unset,
    Object? restSec = _unset,
  }) => ExerciseTargets(
    sets: sets ?? this.sets,
    reps: identical(reps, _unset) ? this.reps : reps as int?,
    durationSec: identical(durationSec, _unset)
        ? this.durationSec
        : durationSec as int?,
    restSec: identical(restSec, _unset) ? this.restSec : restSec as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is ExerciseTargets &&
      other.sets == sets &&
      other.reps == reps &&
      other.durationSec == durationSec &&
      other.restSec == restSec;

  @override
  int get hashCode => Object.hash(sets, reps, durationSec, restSec);

  @override
  String toString() => 'ExerciseTargets($sets, $reps, $durationSec, $restSec)';
}

const Object _unset = Object();
