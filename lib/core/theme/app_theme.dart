import 'package:flutter/material.dart';

import 'gym_colors.dart';
import 'palette.dart';
import 'typography.dart';

/// Hand-made color schemes (SPEC §9: not derived from a seed color).
abstract final class AppColorSchemes {
  static const light = ColorScheme(
    brightness: Brightness.light,
    primary: Palette.plateBlue,
    onPrimary: Palette.white,
    primaryContainer: Palette.blueContainerLight,
    onPrimaryContainer: Palette.blueDeep,
    secondary: Palette.slate,
    onSecondary: Palette.white,
    secondaryContainer: Palette.steelHigh,
    onSecondaryContainer: Palette.iron,
    tertiary: Palette.ochre,
    onTertiary: Palette.white,
    tertiaryContainer: Palette.plateYellow,
    onTertiaryContainer: Palette.iron,
    error: Palette.plateRed,
    onError: Palette.white,
    errorContainer: Palette.redContainerLight,
    onErrorContainer: Palette.redDeep,
    surface: Palette.steel,
    onSurface: Palette.iron,
    surfaceDim: Palette.steelDim,
    surfaceBright: Palette.steelLow,
    surfaceContainerLowest: Palette.steelLowest,
    surfaceContainerLow: Palette.steelLow,
    surfaceContainer: Palette.steelContainer,
    surfaceContainerHigh: Palette.steelHigh,
    surfaceContainerHighest: Palette.steelHighest,
    onSurfaceVariant: Palette.steelText,
    outline: Palette.steelOutline,
    outlineVariant: Palette.steelOutlineVariant,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Palette.ironLight,
    onInverseSurface: Palette.steel,
    inversePrimary: Palette.blueLight,
    surfaceTint: Color(0x00000000),
  );

  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Palette.blueLight,
    onPrimary: Palette.blueDeep,
    primaryContainer: Palette.plateBlue,
    onPrimaryContainer: Palette.white,
    secondary: Palette.ironText,
    onSecondary: Palette.iron,
    secondaryContainer: Palette.ironSecondaryContainer,
    onSecondaryContainer: Palette.steel,
    tertiary: Palette.plateYellow,
    onTertiary: Palette.iron,
    tertiaryContainer: Palette.plateYellow,
    onTertiaryContainer: Palette.iron,
    error: Palette.redLight,
    onError: Palette.redOnLight,
    errorContainer: Palette.plateRed,
    onErrorContainer: Palette.white,
    surface: Palette.iron,
    onSurface: Palette.steel,
    surfaceDim: Palette.iron,
    surfaceBright: Palette.ironHighest,
    surfaceContainerLowest: Palette.ironLowest,
    surfaceContainerLow: Palette.ironLight,
    surfaceContainer: Palette.ironContainer,
    surfaceContainerHigh: Palette.ironHigh,
    surfaceContainerHighest: Palette.ironHighest,
    onSurfaceVariant: Palette.ironText,
    outline: Palette.ironOutline,
    outlineVariant: Palette.ironOutlineVariant,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Palette.steel,
    onInverseSurface: Palette.ironLight,
    inversePrimary: Palette.plateBlue,
    surfaceTint: Color(0x00000000),
  );
}

/// Light and dark [ThemeData] of the app.
abstract final class AppTheme {
  static const cardRadius = 12.0;
  static const buttonRadius = 12.0;
  static const chipRadius = 8.0;

  /// Minimum height of primary actions (SPEC §1).
  static const primaryActionHeight = 56.0;

  /// Minimum height of all other touch targets (SPEC §1).
  static const minTouchTarget = 48.0;

  static ThemeData get light => _build(AppColorSchemes.light, GymColors.light);

  static ThemeData get dark => _build(AppColorSchemes.dark, GymColors.dark);

  static ThemeData _build(ColorScheme scheme, GymColors gym) {
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(buttonRadius)),
    );
    const buttonText = TextStyle(
      fontFamily: Fonts.ui,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    const buttonMinSize = Size(64, minTouchTarget);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      fontFamily: Fonts.ui,
      scaffoldBackgroundColor: scheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      extensions: [gym],
    );

    final text = base.textTheme;
    return base.copyWith(
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: Fonts.ui,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: Fonts.ui,
            fontSize: 13,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gym.action,
          foregroundColor: gym.onAction,
          minimumSize: const Size(64, primaryActionHeight),
          shape: buttonShape,
          textStyle: buttonText.copyWith(fontSize: 18),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(chipRadius)),
        ),
        // Replaces the default label style completely, so the color is required.
        labelStyle: TextStyle(
          fontFamily: Fonts.ui,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: Fonts.ui,
          fontSize: 16,
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(buttonRadius)),
        ),
      ),
      listTileTheme: const ListTileThemeData(minTileHeight: minTouchTarget),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
