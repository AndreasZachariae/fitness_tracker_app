import 'package:flutter/material.dart';

/// Garmin's colors of the heart rate ranges 1–5 (1.6.0): grey, blue, green,
/// orange, red. Index 0 (below range 1) is grey too.
const garminRangeColors = <Color>[
  Color(0xFF9E9E9E),
  Color(0xFF9E9E9E),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFFE53935),
];

Color rangeColor(int range) => garminRangeColors[range.clamp(0, 5)];
