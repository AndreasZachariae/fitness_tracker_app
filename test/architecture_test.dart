import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the architecture rules from SPEC §4 and CLAUDE.md.
void main() {
  List<File> dartFiles(String dir) => Directory(dir).existsSync()
      ? Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
      : <File>[];

  test('domain is pure Dart (no Flutter imports)', () {
    for (final file in dartFiles('lib/domain')) {
      final source = file.readAsStringSync();
      expect(
        RegExp(r'''import\s+['"](package:flutter|dart:ui)''').hasMatch(source),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('no print calls in app code', () {
    for (final file in dartFiles('lib')) {
      if (file.path.endsWith('.g.dart')) continue;
      expect(
        RegExp(r'(^|[^\w.])print\(').hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('main manifest: only the approved permissions', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final permissions = RegExp(r'uses-permission\s+android:name="([^"]+)"')
        .allMatches(manifest)
        .map((m) => m.group(1))
        .toList();
    // Exact alarm for the rest-over vibration in the background (1.0.1).
    // 1.2.0 (approved): notifications, rescheduling after a reboot and the
    // update check on GitHub – the only network access. No
    // REQUEST_INSTALL_PACKAGES: an app that installs downloaded APKs itself
    // is blocked by Play Protect as harmful (1.2.2); the browser does it.
    expect(permissions, [
      'android.permission.VIBRATE',
      'android.permission.USE_EXACT_ALARM',
      'android.permission.SCHEDULE_EXACT_ALARM',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.RECEIVE_BOOT_COMPLETED',
      'android.permission.INTERNET',
    ]);
    expect(
      manifest,
      contains(
        '"android.permission.SCHEDULE_EXACT_ALARM" '
        'android:maxSdkVersion="32"',
      ),
    );
  });

  test('network only for the update check on GitHub (1.2.0)', () {
    const allowed = {'lib/data/notifications/update_checker.dart'};
    final users = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            RegExp(r'HttpClient|package:http/|Socket\b')
                .hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(users.toSet(), allowed);
    final checker = File(allowed.first).readAsStringSync();
    expect(
      RegExp(r'https://([^/\s]+)/')
          .allMatches(checker)
          .map((m) => m.group(1))
          .toSet(),
      {'github.com', 'api.github.com'},
    );
  });

  test('application id and debug suffix are unchanged', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('namespace = "de.gymlog.app"'));
    expect(gradle, contains('applicationId = "de.gymlog.app"'));
    expect(gradle, contains('applicationIdSuffix = ".dev"'));
  });
}
