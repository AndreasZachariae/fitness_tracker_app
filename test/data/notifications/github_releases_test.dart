import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/notifications/update_checker.dart';

/// The parts of the GitHub API answer GymLog reads (1.2.2).
void main() {
  Map<String, Object?> release({
    String tag = 'v1.3.0',
    String name = 'GymLog 1.3.0',
    List<Object?> assets = const [],
  }) => {
    'tag_name': tag,
    'name': name,
    'body': '### Neu\n- Etwas',
    'html_url': 'https://github.com/x/releases/tag/$tag',
    'assets': assets,
  };

  const apk = {
    'name': 'gymlog-1.3.0.apk',
    'size': 20000000,
    'browser_download_url': 'https://github.com/x/download/gymlog-1.3.0.apk',
  };

  test('release app: version from the tag, the APK asset', () {
    final r = GitHubReleases.parse(
      release(
        assets: [
          {'name': 'notes.txt', 'browser_download_url': 'https://x/notes'},
          apk,
        ],
      ),
      dev: false,
    )!;
    expect(r.version, '1.3.0');
    expect(r.notes, '### Neu\n- Etwas');
    expect(r.pageUrl, 'https://github.com/x/releases/tag/v1.3.0');
    expect(r.apkUrl, 'https://github.com/x/download/gymlog-1.3.0.apk');
    expect(r.apkSize, 20000000);
  });

  test('DEV app: version from the title of the pre-release "dev"', () {
    final r = GitHubReleases.parse(
      release(tag: 'dev', name: 'GymLog DEV 1.2.2-dev.31', assets: [apk]),
      dev: true,
    )!;
    expect(r.version, '1.2.2-dev.31');
    expect(GitHubReleases.parse(release(tag: 'dev'), dev: true), isNull);
  });

  test('without APK or with unusable answers', () {
    final r = GitHubReleases.parse(release(), dev: false)!;
    expect((r.apkUrl, r.apkSize), (null, null));
    expect(GitHubReleases.parse(null, dev: false), isNull);
    expect(GitHubReleases.parse(const ['x'], dev: false), isNull);
    expect(GitHubReleases.parse(const <String, Object?>{}, dev: false), isNull);
  });
}
