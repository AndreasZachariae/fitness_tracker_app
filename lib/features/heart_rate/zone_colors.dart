import 'package:flutter/material.dart';

/// Garmin's colors of the heart rate zones 1–5 (1.6.0): grey, blue, green,
/// orange, red. Index 0 (below zone 1) is grey too.
const garminZoneColors = <Color>[
  Color(0xFF9E9E9E),
  Color(0xFF9E9E9E),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFFE53935),
];

Color zoneColor(int zone) => garminZoneColors[zone.clamp(0, 5)];
