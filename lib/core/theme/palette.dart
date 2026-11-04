import 'package:flutter/painting.dart';

/// Raw colors of the "plates and iron" design (SPEC §9).
///
/// Widgets never use these directly; they read [ColorScheme] or `GymColors`
/// from the theme so light and dark mode stay consistent.
abstract final class Palette {
  // Base colors from the spec
  static const iron = Color(0xFF1B1E21);
  static const ironLight = Color(0xFF262A2E);
  static const steel = Color(0xFFE9ECEF);
  static const plateBlue = Color(0xFF1F5FBF);
  static const plateRed = Color(0xFFC8102E);
  static const plateYellow = Color(0xFFF2B705);
  static const plateGreen = Color(0xFF2E8B57);
  static const white = Color(0xFFFFFFFF);

  // Groups (M9): supersets orange between plate red and yellow, rotations
  // in the plate green family.
  static const plateOrange = Color(0xFFE0661A);
  static const orangeDeep = Color(0xFF9E420A);
  static const orangeContainerLight = Color(0xFFFCE7D8);
  static const orangeLight = Color(0xFFF5A066);
  static const orangeContainerDark = Color(0xFF3B2A1E);
  static const greenContainerLight = Color(0xFFDDF0E4);
  static const greenContainerDark = Color(0xFF1D3328);

  // Light mode: neutrals and tones derived for text/icons on steel
  static const steelLowest = Color(0xFFFFFFFF);
  static const steelLow = Color(0xFFF6F7F9);
  static const steelContainer = Color(0xFFDEE2E6);
  static const steelHigh = Color(0xFFD5DADF);
  static const steelHighest = Color(0xFFCBD1D7);
  static const steelDim = Color(0xFFD0D5DA);
  static const steelText = Color(0xFF495057);
  static const steelOutline = Color(0xFF6C757D);
  static const steelOutlineVariant = Color(0xFFC4CAD0);
  static const slate = Color(0xFF4A5560);
  static const blueContainerLight = Color(0xFFD3E1F7);
  static const blueDeep = Color(0xFF0B2A5C);
  static const redContainerLight = Color(0xFFF9D7DC);
  static const redDeep = Color(0xFF5C0614);
  static const greenDeep = Color(0xFF1E6B42);
  static const ochre = Color(0xFF7A5C00);

  // Dark mode: neutrals and lighter plate tones for text/icons on iron
  static const ironLowest = Color(0xFF15171A);
  static const ironContainer = Color(0xFF2A2F33);
  static const ironHigh = Color(0xFF33383D);
  static const ironHighest = Color(0xFF3D4348);
  static const ironText = Color(0xFFB8C0C8);
  static const ironOutline = Color(0xFF8A949E);
  static const ironOutlineVariant = Color(0xFF3F464D);
  static const ironSecondaryContainer = Color(0xFF3A4148);
  static const blueLight = Color(0xFF82AEF0);
  static const redLight = Color(0xFFF28B95);
  static const redOnLight = Color(0xFF4A0410);
  static const greenLight = Color(0xFF5CC98C);
}
