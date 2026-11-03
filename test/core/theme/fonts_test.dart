import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/core/theme/typography.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File('assets/fonts/$file').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

double _width(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  setUpAll(() async {
    await _loadFont(Fonts.ui, ['Barlow-Regular.ttf', 'Barlow-SemiBold.ttf']);
    await _loadFont(Fonts.numbers, ['BarlowSemiCondensed-SemiBold.ttf']);
  });

  // SPEC §9: digits must not jump while counting.
  final styles = {
    'NumberStyles.display': NumberStyles.display,
    'NumberStyles.large': NumberStyles.large,
    'NumberStyles.medium': NumberStyles.medium,
    'NumberStyles.small': NumberStyles.small,
    'Barlow with tabularFigures': const TextStyle(
      fontFamily: Fonts.ui,
      fontSize: 32,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  };

  styles.forEach((name, style) {
    test('$name has tabular figures', () {
      final widths = [for (var d = 0; d <= 9; d++) _width('$d$d$d$d', style)];
      for (final w in widths) {
        expect(w, moreOrLessEquals(widths.first, epsilon: 0.01));
      }
    });
  });

  test('bundled font files exist and the license is bundled', () {
    for (final file in [
      'Barlow-Regular.ttf',
      'Barlow-Medium.ttf',
      'Barlow-SemiBold.ttf',
      'Barlow-Bold.ttf',
      'BarlowSemiCondensed-Medium.ttf',
      'BarlowSemiCondensed-SemiBold.ttf',
      'BarlowSemiCondensed-Bold.ttf',
      'OFL.txt',
    ]) {
      expect(File('assets/fonts/$file').existsSync(), isTrue, reason: file);
    }
  });

  test('key numbers are at least 32 sp (SPEC §9)', () {
    for (final style in [
      NumberStyles.display,
      NumberStyles.large,
      NumberStyles.medium,
    ]) {
      expect(style.fontSize, greaterThanOrEqualTo(32));
    }
  });
}
