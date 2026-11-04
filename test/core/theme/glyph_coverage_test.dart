import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Code points of a TrueType font (cmap formats 4 and 12).
Set<int> _codePoints(String path) {
  final d = ByteData.sublistView(File(path).readAsBytesSync());
  final tables = d.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < tables; i++) {
    final rec = 12 + 16 * i;
    final tag = String.fromCharCodes([
      for (var k = 0; k < 4; k++) d.getUint8(rec + k),
    ]);
    if (tag == 'cmap') cmap = d.getUint32(rec + 8);
  }
  final result = <int>{};
  final subtables = d.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final start = cmap + d.getUint32(cmap + 4 + 8 * i + 4);
    switch (d.getUint16(start)) {
      case 4:
        final segments = d.getUint16(start + 6) ~/ 2;
        for (var s = 0; s < segments; s++) {
          final end = d.getUint16(start + 14 + 2 * s);
          final first = d.getUint16(start + 16 + 2 * segments + 2 * s);
          for (var c = first; c <= end && c != 0xFFFF; c++) {
            result.add(c);
          }
        }
      case 12:
        final groups = d.getUint32(start + 12);
        for (var g = 0; g < groups; g++) {
          final first = d.getUint32(start + 16 + 12 * g);
          final end = d.getUint32(start + 20 + 12 * g);
          for (var c = first; c <= end; c++) {
            result.add(c);
          }
        }
    }
  }
  return result;
}

/// Every character of the UI texts must exist in the bundled fonts, or it
/// shows as a box (M9: "→" was missing in Barlow).
void main() {
  final text = File('lib/core/l10n/strings_de.dart')
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
  final used = {
    for (final r in text.runes)
      if (r > 127) r,
  };

  for (final font in [
    'Barlow-Regular.ttf',
    'Barlow-SemiBold.ttf',
    'Barlow-Bold.ttf',
    'BarlowSemiCondensed-SemiBold.ttf',
  ]) {
    test('$font has every character of strings_de.dart', () {
      final available = _codePoints('assets/fonts/$font');
      final missing = [
        for (final r in used)
          if (!available.contains(r)) String.fromCharCode(r),
      ];
      expect(missing, isEmpty);
    });
  }
}
