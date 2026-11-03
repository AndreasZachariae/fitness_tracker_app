import 'package:flutter/services.dart';

/// Light feedback after saving a set. Failures are ignored: the set is
/// already stored, a missing vibration must never look like an error.
Future<void> lightHaptic() async {
  try {
    await HapticFeedback.lightImpact();
  } on Object {
    // No haptics available.
  }
}
