import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/clock.dart';

void main() {
  test('SystemClock returns UTC', () {
    expect(const SystemClock().now().isUtc, isTrue);
  });

  test('FixedClock stores UTC and advances', () {
    final clock = FixedClock(DateTime.utc(2026, 11, 3, 17, 20));
    expect(clock.now(), DateTime.utc(2026, 11, 3, 17, 20));

    clock.advance(const Duration(minutes: 90));
    expect(clock.now(), DateTime.utc(2026, 11, 3, 18, 50));

    clock.time = DateTime(2026, 11, 4, 8);
    expect(clock.now().isUtc, isTrue);
  });

  test('clockProvider can be overridden', () {
    final fixed = FixedClock(DateTime.utc(2026, 1, 1));
    final container = ProviderContainer.test(
      overrides: [clockProvider.overrideWithValue(fixed)],
    );
    expect(container.read(clockProvider).now(), DateTime.utc(2026, 1, 1));
  });

  test('clockProvider defaults to SystemClock', () {
    final container = ProviderContainer.test();
    expect(container.read(clockProvider), isA<SystemClock>());
  });
}
