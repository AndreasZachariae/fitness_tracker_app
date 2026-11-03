/// CSV after RFC 4180 (SPEC §8.1): comma separator, point as decimal
/// separator, CRLF line ends, quoting where needed, empty field for null.
library;

/// One CSV field.
String csvField(Object? value) {
  if (value == null) return '';
  final text = switch (value) {
    final double d => formatCsvNumber(d),
    final bool b => b ? 'true' : 'false',
    _ => value.toString(),
  };
  final needsQuotes =
      text.contains(',') ||
      text.contains('"') ||
      text.contains('\n') ||
      text.contains('\r') ||
      text != text.trim();
  return needsQuotes ? '"${text.replaceAll('"', '""')}"' : text;
}

/// `62.5`, `80` (no `.0`), at most 2 decimals.
String formatCsvNumber(double value) {
  final rounded = (value * 100).round() / 100;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}

/// A complete CSV document with header.
String toCsv(List<String> header, Iterable<List<Object?>> rows) {
  final buffer = StringBuffer()..write(header.map(csvField).join(','));
  buffer.write('\r\n');
  for (final row in rows) {
    buffer
      ..write(row.map(csvField).join(','))
      ..write('\r\n');
  }
  return buffer.toString();
}

/// Local time as ISO 8601 with offset: `2026-11-03T18:20:00+01:00`.
String isoWithOffset(DateTime time) {
  final local = time.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final h = offset.inHours.abs().toString().padLeft(2, '0');
  final m = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:'
      '${two(local.second)}$sign$h:$m';
}
