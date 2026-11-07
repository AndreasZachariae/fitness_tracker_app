import '../../domain/set_validation.dart';

/// Errors of the data layer that the UI turns into German messages.
sealed class RepositoryException implements Exception {
  const RepositoryException();
}

/// A name is empty or too long.
final class InvalidNameException extends RepositoryException {
  const InvalidNameException(this.name);

  final String name;

  @override
  String toString() => 'InvalidNameException($name)';
}

/// An exercise or plan with this name (ignoring case) already exists.
final class DuplicateNameException extends RepositoryException {
  const DuplicateNameException(this.name);

  final String name;

  @override
  String toString() => 'DuplicateNameException($name)';
}

/// A value is outside its allowed range (e.g. target sets 1–10).
final class InvalidValueException extends RepositoryException {
  const InvalidValueException(this.field, this.value);

  final String field;
  final Object? value;

  @override
  String toString() => 'InvalidValueException($field = $value)';
}

/// The referenced row does not exist (anymore).
final class NotFoundException extends RepositoryException {
  const NotFoundException(this.entity, this.id);

  final String entity;
  final int id;

  @override
  String toString() => 'NotFoundException($entity $id)';
}

/// The exercise is already part of the plan or session.
final class DuplicateExerciseException extends RepositoryException {
  const DuplicateExerciseException(this.exerciseId);

  final int exerciseId;

  @override
  String toString() => 'DuplicateExerciseException($exerciseId)';
}

/// The type of an exercise with training history cannot change: its sets
/// would no longer fit the type.
final class TypeChangeNotAllowedException extends RepositoryException {
  const TypeChangeNotAllowedException(this.exerciseId);

  final int exerciseId;

  @override
  String toString() => 'TypeChangeNotAllowedException($exerciseId)';
}

/// A session is already running; at most one may be active.
/// The exercise has sets stored as level numbers (levels without kg) and
/// would switch to kg, or the other way round, without kg per level to
/// convert them (1.1.0).
final class StepChangeNotAllowedException extends RepositoryException {
  const StepChangeNotAllowedException(this.exerciseId);

  final int exerciseId;

  @override
  String toString() => 'StepChangeNotAllowedException($exerciseId)';
}

final class ActiveSessionExistsException extends RepositoryException {
  const ActiveSessionExistsException(this.activeSessionId);

  final int activeSessionId;

  @override
  String toString() => 'ActiveSessionExistsException($activeSessionId)';
}

/// The session is already finished and cannot take new sets this way.
final class SessionNotActiveException extends RepositoryException {
  const SessionNotActiveException(this.sessionId);

  final int sessionId;

  @override
  String toString() => 'SessionNotActiveException($sessionId)';
}

/// The values of a set do not fit the exercise type.
final class InvalidSetException extends RepositoryException {
  const InvalidSetException(this.error);

  final SetValidationError error;

  @override
  String toString() => 'InvalidSetException(${error.name})';
}
