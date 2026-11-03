import 'package:flutter/painting.dart';

/// Font families bundled under `assets/fonts/` (SPEC §9).
abstract final class Fonts {
  /// UI text.
  static const ui = 'Barlow';

  /// Large numbers: weight, reps, timers.
  static const numbers = 'BarlowSemiCondensed';
}

/// Text styles for numbers. Always tabular figures so digits do not jump
/// while counting. Colors are inherited from the surrounding text style.
abstract final class NumberStyles {
  static const _tabular = [FontFeature.tabularFigures()];

  /// Hero numbers, e.g. the running stopwatch.
  static const display = TextStyle(
    fontFamily: Fonts.numbers,
    fontSize: 56,
    fontWeight: FontWeight.w600,
    height: 1.1,
    fontFeatures: _tabular,
  );

  /// Stepper values (weight, reps, duration).
  static const large = TextStyle(
    fontFamily: Fonts.numbers,
    fontSize: 40,
    fontWeight: FontWeight.w600,
    height: 1.1,
    fontFeatures: _tabular,
  );

  /// Session and rest timer; smallest size for key numbers (≥ 32 sp).
  static const medium = TextStyle(
    fontFamily: Fonts.numbers,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.1,
    fontFeatures: _tabular,
  );

  /// Secondary numbers in lists and tiles.
  static const small = TextStyle(
    fontFamily: Fonts.numbers,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.2,
    fontFeatures: _tabular,
  );
}
