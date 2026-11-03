import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/format/formatters.dart';

void main() {
  group('formatKg', () {
    const cases = <(double, String)>[
      (62.5, '62,5 kg'),
      (100, '100 kg'),
      (0, '0 kg'),
      (1.25, '1,25 kg'),
      (1250, '1.250 kg'),
      (-20, '-20 kg'),
    ];
    for (final (input, expected) in cases) {
      test('$input → $expected', () => expect(formatKg(input), expected));
    }
  });

  group('formatHms', () {
    const cases = <(Duration, String)>[
      (Duration.zero, '0:00:00'),
      (Duration(minutes: 42, seconds: 13), '0:42:13'),
      (Duration(hours: 1, minutes: 5), '1:05:00'),
      (Duration(hours: 12, seconds: 9), '12:00:09'),
      (Duration(seconds: -5), '0:00:00'),
    ];
    for (final (input, expected) in cases) {
      test('$input → $expected', () => expect(formatHms(input), expected));
    }
  });

  group('formatMinSec', () {
    const cases = <(Duration, String)>[
      (Duration.zero, '0:00'),
      (Duration(seconds: 72), '1:12'),
      (Duration(minutes: 12, seconds: 5), '12:05'),
      (Duration(seconds: -1), '0:00'),
    ];
    for (final (input, expected) in cases) {
      test('$input → $expected', () => expect(formatMinSec(input), expected));
    }
  });

  group('parseDecimal', () {
    const cases = <String, double?>{
      '62,5': 62.5,
      '62.5': 62.5,
      ' 80 ': 80,
      '0': 0,
      ',5': 0.5,
      '7,': 7,
      '-20': -20,
      '+2,5': 2.5,
      '': null,
      '   ': null,
      'abc': null,
      '1,2,3': null,
      '1.250,5': null,
      '62,5 kg': null,
    };
    cases.forEach((input, expected) {
      test('"$input" → $expected', () {
        expect(parseDecimal(input), expected);
      });
    });
  });
}
