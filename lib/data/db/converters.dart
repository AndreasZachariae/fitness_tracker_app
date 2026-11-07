import 'package:drift/drift.dart';

import '../../domain/models/enums.dart';
import '../../domain/models/local_date.dart';

/// Stores a [Coded] enum as its code.
class CodedConverter<T extends Coded> extends TypeConverter<T, String> {
  const CodedConverter(this.values);

  final List<T> values;

  @override
  T fromSql(String fromDb) => byCode(values, fromDb);

  @override
  String toSql(T value) => value.code;
}

class ExerciseTypeConverter extends CodedConverter<ExerciseType> {
  const ExerciseTypeConverter() : super(ExerciseType.values);
}

class ExerciseCategoryConverter extends CodedConverter<ExerciseCategory> {
  const ExerciseCategoryConverter() : super(ExerciseCategory.values);
}

class SessionExerciseStatusConverter
    extends CodedConverter<SessionExerciseStatus> {
  const SessionExerciseStatusConverter() : super(SessionExerciseStatus.values);
}

class PlanGroupKindConverter extends CodedConverter<PlanGroupKind> {
  const PlanGroupKindConverter() : super(PlanGroupKind.values);
}

class StepModeConverter extends CodedConverter<StepMode> {
  const StepModeConverter() : super(StepMode.values);
}

class WeightUnitConverter extends CodedConverter<WeightUnit> {
  const WeightUnitConverter() : super(WeightUnit.values);
}

class ThemePreferenceConverter extends CodedConverter<ThemePreference> {
  const ThemePreferenceConverter() : super(ThemePreference.values);
}

/// Stores a [LocalDate] as `YYYY-MM-DD`.
class LocalDateConverter extends TypeConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromSql(String fromDb) => LocalDate.parse(fromDb);

  @override
  String toSql(LocalDate value) => value.toIsoString();
}
