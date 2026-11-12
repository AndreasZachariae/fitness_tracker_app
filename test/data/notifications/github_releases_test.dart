import 'dart:convert';
import 'dart:io';

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
    'url': 'https://api.github.com/repos/x/y/releases/assets/7',
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
    // 1.6.2: the asset address for the in-app download.
    expect(r.apkAssetUrl, 'https://api.github.com/repos/x/y/releases/assets/7');
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

  test('asks with the ETag; "unchanged" keeps the release (1.2.2)', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final seen = <String?>[];
    var status = 200;
    server.listen((request) async {
      seen.add(request.headers.value(HttpHeaders.ifNoneMatchHeader));
      final response = request.response;
      if (status == 304 &&
          request.headers.value(HttpHeaders.ifNoneMatchHeader) == '"v1"') {
        response.statusCode = 304;
      } else if (status == 500) {
        response.statusCode = 500;
      } else {
        response.headers.set(HttpHeaders.etagHeader, '"v1"');
        response.write(jsonEncode(release(assets: [apk])));
      }
      await response.close();
    });
    final source = GitHubReleases(
      dev: false,
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/releases/latest'),
    );

    expect((await source.latest())?.version, '1.3.0');
    status = 304;
    final again = await source.latest();
    expect(again?.version, '1.3.0');
    expect(again?.apkUrl, apk['browser_download_url']);
    status = 500;
    expect(await source.latest(), isNull);
    expect(seen, [null, '"v1"', '"v1"']);
  });
}
