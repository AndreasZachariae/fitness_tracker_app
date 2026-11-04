/// Enums of the data model with their stable storage codes (SPEC §5).
///
/// The codes are written to the database, CSV and backups. Never change an
/// existing code; only add new values.
library;

/// An enum value with a stable storage code.
abstract interface class Coded {
  String get code;
}

/// Looks up the value of [values] with the given [code].
///
/// Throws a [FormatException] for unknown codes so corrupt data is noticed.
T byCode<T extends Coded>(List<T> values, String code) {
  for (final value in values) {
    if (value.code == code) return value;
  }
  throw FormatException('Unknown code for $T', code);
}

enum ExerciseType implements Coded {
  weightReps('weight_reps'),
  bodyweight('bodyweight'),
  timed('timed');

  const ExerciseType(this.code);

  @override
  final String code;

  /// Default of `includeInStrengthIndex` for new exercises (SPEC §5).
  bool get includeInStrengthIndexByDefault => this != ExerciseType.timed;

  static ExerciseType fromCode(String code) => byCode(values, code);
}

enum ExerciseCategory implements Coded {
  chest('chest'),
  back('back'),
  legs('legs'),
  shoulders('shoulders'),
  arms('arms'),
  core('core'),
  fullBody('full_body'),
  other('other');

  const ExerciseCategory(this.code);

  @override
  final String code;

  static ExerciseCategory fromCode(String code) => byCode(values, code);
}

enum SessionExerciseStatus implements Coded {
  pending('pending'),
  active('active'),
  done('done'),
  skipped('skipped');

  const SessionExerciseStatus(this.code);

  @override
  final String code;

  static SessionExerciseStatus fromCode(String code) => byCode(values, code);
}

/// Theme preference stored in the settings.
enum ThemePreference implements Coded {
  system('system'),
  light('light'),
  dark('dark');

  const ThemePreference(this.code);

  @override
  final String code;

  static ThemePreference fromCode(String code) => byCode(values, code);
}

/// Kind of a group of plan exercises (M9).
enum PlanGroupKind implements Coded {
  /// Exercises done alternately, rest only after each round.
  superset('superset'),

  /// One exercise per training, the next one after `rotationEvery` trainings.
  rotation('rotation');

  const PlanGroupKind(this.code);

  @override
  final String code;

  static PlanGroupKind fromCode(String code) => byCode(values, code);
}
