import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/rest_timer.dart';

void main() {
  test('rest duration: session exercise → exercise → default', () {
    expect(
      restDurationSec(
        sessionExerciseRestSec: 60,
        exerciseRestSec: 120,
        defaultRestSec: 90,
      ),
      60,
    );
    expect(
      restDurationSec(
        sessionExerciseRestSec: null,
        exerciseRestSec: 120,
        defaultRestSec: 90,
      ),
      120,
    );
    expect(
      restDurationSec(
        sessionExerciseRestSec: null,
        exerciseRestSec: null,
        defaultRestSec: 90,
      ),
      90,
    );
  });

  final set = DateTime.utc(2026, 11, 3, 17);
  RestState at(int seconds, {int adjust = 0}) => restState(
    lastSetAt: set,
    durationSec: 90,
    adjustSec: adjust,
    now: set.add(Duration(seconds: seconds)),
  );

  test('running with remaining time and progress', () {
    final s = at(30) as RestRunning;
    expect(s.remaining, const Duration(seconds: 60));
    expect(s.progress, closeTo(1 / 3, 1e-9));
  });

  test('±15 s adjustments move the end', () {
    expect((at(30, adjust: 15) as RestRunning).remaining.inSeconds, 75);
    expect(at(80, adjust: -15), isA<RestOver>());
  });

  test('"Pause vorbei" for 10 s, then hidden', () {
    expect(at(90), isA<RestOver>());
    expect(at(99), isA<RestOver>());
    expect(at(100), isA<RestHidden>());
  });

  test('reconstructable after a restart: only stored time matters', () {
    expect((at(45) as RestRunning).remaining.inSeconds, 45);
  });
}
