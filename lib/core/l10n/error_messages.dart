import '../../data/repositories/repository_exceptions.dart';
import 'strings_de.dart';

/// A German message for an error from the data layer.
String errorMessage(Object error) => switch (error) {
  InvalidNameException() => S.errorNameRequired,
  DuplicateNameException() => S.errorExerciseNameTaken,
  InvalidValueException() => S.errorInvalidValue,
  NotFoundException() => S.errorNotFound,
  DuplicateExerciseException() => S.errorDuplicateExercise,
  TypeChangeNotAllowedException() => S.typeLocked,
  ActiveSessionExistsException() => S.errorActiveSession,
  SessionNotActiveException() => S.errorSessionNotActive,
  InvalidSetException() => S.errorInvalidSet,
  _ => S.errorUnexpected,
};
