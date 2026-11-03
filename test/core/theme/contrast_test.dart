import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/theme/app_theme.dart';
import 'package:gymlog/core/theme/gym_colors.dart';

/// WCAG 2 contrast ratio.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

const text = 4.5;
const large = 3.0;

void main() {
  for (final (name, scheme, gym) in [
    ('light', AppColorSchemes.light, GymColors.light),
    ('dark', AppColorSchemes.dark, GymColors.dark),
  ]) {
    group('$name contrast (SPEC §9)', () {
      final backgrounds = {
        'surface': scheme.surface,
        'card': scheme.surfaceContainerLow,
        'navigationBar': scheme.surfaceContainer,
      };
      final foregroundsOnBackground = <String, (Color, double)>{
        'onSurface': (scheme.onSurface, text),
        'onSurfaceVariant': (scheme.onSurfaceVariant, text),
        'primary': (scheme.primary, text),
        'error': (scheme.error, text),
        'tertiary': (scheme.tertiary, text),
        'success': (gym.success, text),
        'rest': (gym.rest, text),
        'record': (gym.record, text),
        'activeEdge': (gym.activeEdge, large),
        'outline': (scheme.outline, large),
      };
      for (final bg in backgrounds.entries) {
        for (final fg in foregroundsOnBackground.entries) {
          test('${fg.key} on ${bg.key}', () {
            expect(
              contrast(fg.value.$1, bg.value),
              greaterThanOrEqualTo(fg.value.$2),
            );
          });
        }
      }

      final pairs = <String, (Color, Color, double)>{
        'onPrimary/primary': (scheme.onPrimary, scheme.primary, text),
        'onPrimaryContainer/primaryContainer': (
          scheme.onPrimaryContainer,
          scheme.primaryContainer,
          text,
        ),
        'onSecondaryContainer/secondaryContainer': (
          scheme.onSecondaryContainer,
          scheme.secondaryContainer,
          text,
        ),
        'onTertiaryContainer/tertiaryContainer': (
          scheme.onTertiaryContainer,
          scheme.tertiaryContainer,
          text,
        ),
        'onError/error': (scheme.onError, scheme.error, text),
        'onErrorContainer/errorContainer': (
          scheme.onErrorContainer,
          scheme.errorContainer,
          text,
        ),
        'onInverseSurface/inverseSurface': (
          scheme.onInverseSurface,
          scheme.inverseSurface,
          text,
        ),
        'inversePrimary/inverseSurface': (
          scheme.inversePrimary,
          scheme.inverseSurface,
          text,
        ),
        'onAction/action': (gym.onAction, gym.action, text),
        'onRestContainer/restContainer': (
          gym.onRestContainer,
          gym.restContainer,
          text,
        ),
        'onRecordContainer/recordContainer': (
          gym.onRecordContainer,
          gym.recordContainer,
          text,
        ),
        // Only large or bold text on green (documented in PROGRESS.md).
        'onSuccessContainer/successContainer': (
          gym.onSuccessContainer,
          gym.successContainer,
          large,
        ),
      };
      for (final pair in pairs.entries) {
        test(pair.key, () {
          expect(
            contrast(pair.value.$1, pair.value.$2),
            greaterThanOrEqualTo(pair.value.$3),
          );
        });
      }
    });
  }

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    test('$name chip labels are readable', () {
      final color = theme.chipTheme.labelStyle?.color;
      expect(color, isNotNull);
      for (final bg in [
        theme.colorScheme.surface,
        theme.colorScheme.secondaryContainer,
      ]) {
        expect(contrast(color!, bg), greaterThanOrEqualTo(text));
      }
    });
  }

  test('themes carry GymColors and the plate blue action color', () {
    expect(AppTheme.light.extension<GymColors>(), GymColors.light);
    expect(AppTheme.dark.extension<GymColors>(), GymColors.dark);
    expect(GymColors.light.action, const Color(0xFF1F5FBF));
    expect(GymColors.dark.action, const Color(0xFF1F5FBF));
  });
}
