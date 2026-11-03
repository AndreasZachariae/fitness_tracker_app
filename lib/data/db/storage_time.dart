/// Normalizes a point in time for storage: UTC with millisecond precision.
///
/// Times are stored as ISO-8601 text. A uniform format
/// (`2026-11-03T17:20:00.000Z`) keeps SQL ordering chronological; extra
/// microsecond digits would break it. Every write goes through this.
DateTime storageTime(DateTime time) => DateTime.fromMillisecondsSinceEpoch(
  time.millisecondsSinceEpoch,
  isUtc: true,
);
