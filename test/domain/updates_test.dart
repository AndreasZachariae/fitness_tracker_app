import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/updates.dart';

void main() {
  test('1.6.2: APK file name carries the version', () {
    expect(apkFileName('1.6.2'), 'gymlog-1.6.2.apk');
    expect(apkFileName('1.6.2-dev.53'), 'gymlog-1.6.2-dev.53.apk');
    // Two DEV builds from the same URL get different names.
    expect(apkFileName('1.6.2-dev.54'), isNot(apkFileName('1.6.2-dev.53')));
    expect(apkFileName('1.6/2 x'), 'gymlog-1.6_2_x.apk');
  });

  test('isNewerVersion: release app', () {
    expect(isNewerVersion('v1.3.0', '1.2.0'), isTrue);
    expect(isNewerVersion('v1.2.1', '1.2.0+15'), isTrue);
    expect(isNewerVersion('1.2.1', '1.2.1'), isFalse);
    expect(isNewerVersion('v1.2.0', '1.2.0'), isFalse);
    expect(isNewerVersion('v1.1.9', '1.2.0'), isFalse);
    expect(isNewerVersion('v2.0.0', '1.10.4'), isTrue);
    expect(isNewerVersion('nightly', '1.2.0'), isFalse);
  });

  test('isNewerVersion: DEV app compares only the commit counter', () {
    expect(isNewerVersion('1.2.2-dev.31', '1.2.1-dev.30'), isTrue);
    expect(isNewerVersion('1.2.2-dev.31', '1.2.2-dev.31'), isFalse);
    expect(isNewerVersion('1.2.2-dev.30', '1.2.2-dev.31'), isFalse);
    // The counter decides, also across a version bump.
    expect(isNewerVersion('1.2.2-dev.40', '1.3.0-dev.39'), isTrue);
    // Mixed: never (a local build without counter is not pestered).
    expect(isNewerVersion('1.2.2-dev.31', '1.2.1'), isFalse);
    expect(isNewerVersion('1.3.0', '1.2.2-dev.31'), isFalse);
  });

  test('DEV version from the title of the pre-release', () {
    expect(devVersionIn('GymLog DEV 1.2.2-dev.31'), '1.2.2-dev.31');
    expect(devVersionIn('GymLog 1.2.2'), isNull);
    expect(devBuildOf('1.2.2-dev.31'), 31);
    expect(devBuildOf('1.2.2'), isNull);
  });

  group('parseReleaseNotes', () {
    test('DEV release: test list, changes; commits and footer left out', () {
      const md = '''
Vorab-Version zum Testen: **GymLog DEV 1.2.2-dev.31** – nur für die DEV-App.

## Testliste fürs Handy

**1.2.2 DEV-App über GitHub**
Nur, was live ausprobiert werden muss.
- [ ] Update-Seite öffnet sich
  und zeigt die Testliste.
- [x] Erledigt

## Änderungen

### Neu
- **Updates:** direkt `installieren`, siehe [GitHub](https://github.com).
  - Unterpunkt

<details>
<summary>Commits seit v1.2.1 (für Entwickler)</summary>

#### Features
- something (`abc1234`)

</details>

---

### Installieren
1. APK laden
''';
      final blocks = parseReleaseNotes(md);
      expect(blocks.map((b) => b.toString()), [
        'NoteBlockKind.paragraph(0): Vorab-Version zum Testen: '
            'GymLog DEV 1.2.2-dev.31 – nur für die DEV-App.',
        'NoteBlockKind.heading(2): Testliste fürs Handy',
        'NoteBlockKind.paragraph(0): 1.2.2 DEV-App über GitHub',
        'NoteBlockKind.paragraph(0): Nur, was live ausprobiert werden muss.',
        'NoteBlockKind.task(0): Update-Seite öffnet sich und zeigt die '
            'Testliste.',
        'NoteBlockKind.task(0): Erledigt',
        'NoteBlockKind.heading(2): Änderungen',
        'NoteBlockKind.heading(3): Neu',
        'NoteBlockKind.bullet(0): Updates: direkt installieren, siehe '
            'GitHub.',
        'NoteBlockKind.bullet(1): Unterpunkt',
      ]);
      expect(blocks[0].spans[1], (
        text: 'GymLog DEV 1.2.2-dev.31',
        bold: true,
        code: false,
      ));
    });

    test('inline: bold, code and links', () {
      expect(parseInline('a **b** `c` [d](e) f'), [
        (text: 'a ', bold: false, code: false),
        (text: 'b', bold: true, code: false),
        (text: ' ', bold: false, code: false),
        (text: 'c', bold: false, code: true),
        (text: ' d f', bold: false, code: false),
      ]);
      expect(parseReleaseNotes(''), isEmpty);
      expect(parseReleaseNotes('\r\n\r\n'), isEmpty);
    });
  });
}
