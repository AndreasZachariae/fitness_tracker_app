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

/// How the weight of an exercise goes up and down (1.1.0).
enum StepMode implements Coded {
  /// The default step of the settings (e.g. 15 lbs).
  standard('standard'),

  /// An own step in kg (`incrementKg`).
  kg('kg'),

  /// An own step in lbs (`incrementLbs`) on machines with lbs plates.
  lbs('lbs'),

  /// Numbered levels (e.g. 1–15), optionally with known kg per level
  /// (`levelKg`).
  levels('levels');

  const StepMode(this.code);

  @override
  final String code;

  static StepMode fromCode(String code) => byCode(values, code);
}

/// Unit of the default weight step in the settings (1.1.0).
enum WeightUnit implements Coded {
  kg('kg'),
  lbs('lbs');

  const WeightUnit(this.code);

  @override
  final String code;

  static WeightUnit fromCode(String code) => byCode(values, code);
}

/// For the calorie estimate (1.6.0); the formula knows only these two.
enum Sex implements Coded {
  male('male'),
  female('female');

  const Sex(this.code);

  @override
  final String code;

  static Sex fromCode(String code) => byCode(values, code);
}
