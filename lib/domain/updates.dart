/// Versions and release notes of GymLog updates (1.2.0, DEV channel and
/// notes in the app since 1.2.2). Pure Dart.
library;

final _stable = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$');
final _dev = RegExp(r'(\d+\.\d+\.\d+)-dev\.(\d+)');

/// Build counter of a DEV version such as `1.2.2-dev.31` (31), else null.
int? devBuildOf(String version) {
  final match = _dev.firstMatch(version);
  return match == null ? null : int.parse(match.group(2)!);
}

/// The DEV version in the title of the pre-release "dev", e.g.
/// `GymLog DEV 1.2.2-dev.31` → `1.2.2-dev.31`.
String? devVersionIn(String text) => _dev.firstMatch(text)?.group(0);

/// File name of the downloaded update APK (1.6.2): with the version, so a
/// newer APK is never mistaken for the one already there (the DEV release
/// always has the same URL), e.g. `gymlog-1.6.2-dev.53.apk`.
String apkFileName(String version) =>
    'gymlog-${version.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.apk';

/// Whether release [latest] is newer than the installed [current].
///
/// Release app: `v1.3.0` against `1.2.0` (build numbers ignored).
/// DEV app: `1.2.2-dev.31` against `1.2.1-dev.30` – only the counter (the
/// number of commits) counts. Mixed or unknown forms are never newer, so a
/// local build without counter is not pestered with updates.
bool isNewerVersion(String latest, String current) {
  final devLatest = devBuildOf(latest);
  final devCurrent = devBuildOf(current);
  if (devLatest != null || devCurrent != null) {
    return devLatest != null && devCurrent != null && devLatest > devCurrent;
  }
  List<int>? parse(String v) {
    final match = _stable.firstMatch(v.trim());
    if (match == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  }

  final a = parse(latest);
  final b = parse(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// Part of a line of release notes.
typedef NoteSpan = ({String text, bool bold, bool code});

enum NoteBlockKind { heading, bullet, task, paragraph }

/// One line (or wrapped list entry) of release notes.
final class NoteBlock {
  const NoteBlock(this.kind, this.spans, {this.level = 0});

  final NoteBlockKind kind;
  final List<NoteSpan> spans;

  /// Heading: 2 for `##`, 3 for `###`, …; lists: indentation depth.
  final int level;

  String get text => spans.map((s) => s.text).join();

  @override
  String toString() => '$kind($level): $text';
}

/// The Markdown of a GitHub release as simple blocks for the app.
///
/// Leaves out what only matters on GitHub: the commit list for developers
/// (`<details>`) and everything after the first `---` (how to install).
/// Understands headings, lists, task lists (`- [ ]`), **bold**, `code` and
/// links (shown as their text).
List<NoteBlock> parseReleaseNotes(String markdown) {
  final blocks = <NoteBlock>[];
  var inDetails = false;
  NoteBlockKind? openKind;
  var openLevel = 0;
  final open = StringBuffer();

  void flush() {
    if (openKind != null && open.isNotEmpty) {
      blocks.add(
        NoteBlock(openKind!, parseInline(open.toString()), level: openLevel),
      );
    }
    openKind = null;
    open.clear();
  }

  void start(NoteBlockKind kind, String text, {int level = 0}) {
    flush();
    openKind = kind;
    openLevel = level;
    open.write(text.trim());
  }

  for (final raw in markdown.replaceAll('\r', '').split('\n')) {
    final line = raw.trimRight();
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('<details')) {
      flush();
      inDetails = true;
      continue;
    }
    if (trimmed.startsWith('</details')) {
      inDetails = false;
      continue;
    }
    if (inDetails) continue;
    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) break;
    if (trimmed.isEmpty) {
      flush();
      continue;
    }
    final indent = (line.length - trimmed.length) ~/ 2;
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    final task = RegExp(r'^[-*+]\s+\[[ xX]\]\s+(.*)$').firstMatch(trimmed);
    final bullet = RegExp(r'^(?:[-*+]|\d+\.)\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      start(
        NoteBlockKind.heading,
        heading.group(2)!,
        level: heading.group(1)!.length,
      );
      flush();
    } else if (task != null) {
      start(NoteBlockKind.task, task.group(1)!, level: indent);
    } else if (bullet != null) {
      start(NoteBlockKind.bullet, bullet.group(1)!, level: indent);
    } else if (indent > 0 &&
        (openKind == NoteBlockKind.bullet || openKind == NoteBlockKind.task)) {
      // A wrapped, indented line continues the list entry above.
      open
        ..write(' ')
        ..write(trimmed);
    } else {
      start(NoteBlockKind.paragraph, trimmed);
    }
  }
  flush();
  return blocks;
}

/// `**bold**`, `` `code` `` and `[text](url)` of one line.
List<NoteSpan> parseInline(String text) {
  final spans = <NoteSpan>[];
  final plain = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]*\)'),
    (m) => m.group(1)!,
  );
  final token = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
  var at = 0;
  for (final m in token.allMatches(plain)) {
    if (m.start > at) {
      spans.add((text: plain.substring(at, m.start), bold: false, code: false));
    }
    if (m.group(1) != null) {
      spans.add((text: m.group(1)!, bold: true, code: false));
    } else {
      spans.add((text: m.group(2)!, bold: false, code: true));
    }
    at = m.end;
  }
  if (at < plain.length) {
    spans.add((text: plain.substring(at), bold: false, code: false));
  }
  return spans;
}
