import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of the current time. All code reads time through this abstraction
/// so tests can control it.
///
/// [now] always returns a UTC [DateTime]; convert to local time only for
/// display and for day/week bucketing.
abstract interface class Clock {
  DateTime now();
}

/// Real wall-clock time.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// Clock with a manually controlled time, for tests and previews.
final class FixedClock implements Clock {
  FixedClock(DateTime time) : _time = time.toUtc();

  DateTime _time;

  @override
  DateTime now() => _time;

  /// Sets the current time.
  set time(DateTime value) => _time = value.toUtc();

  /// Moves the current time forward by [duration].
  void advance(Duration duration) => _time = _time.add(duration);
}

/// Injectable clock. Override in tests with a [FixedClock].
final clockProvider = Provider<Clock>((ref) => const SystemClock());
