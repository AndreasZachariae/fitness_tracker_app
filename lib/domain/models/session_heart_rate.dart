import '../heart_rate.dart';

/// What is kept of a training's heart rate (table `session_heart_rates`,
/// 1.5.1): key figures, the distribution and a curve with one value per
/// minute – not the series itself.
final class SessionHeartRate {
  const SessionHeartRate({
    required this.sessionId,
    required this.avgBpm,
    required this.maxBpm,
    required this.minBpm,
    required this.seconds,
    required this.histogram,
    required this.curve,
    this.recoveryBpm,
  });

  factory SessionHeartRate.fromSummary(int sessionId, HeartRateSummary s) =>
      SessionHeartRate(
        sessionId: sessionId,
        avgBpm: s.average,
        maxBpm: s.max,
        minBpm: s.min,
        seconds: s.seconds,
        histogram: encodeHistogram(s.histogram),
        curve: encodeCurve(s.curve),
      );

  final int sessionId;
  final int avgBpm;
  final int maxBpm;
  final int minBpm;

  /// Seconds with heart rate.
  final int seconds;

  /// [encodeHistogram]: seconds per beats per minute.
  final String histogram;

  /// [encodeCurve]: average per minute since the start.
  final String curve;

  /// Heart rate recovery: average drop in the 60 s after hard sets
  /// (1.6.0); null if no set was usable.
  final int? recoveryBpm;

  Map<int, int> get distribution => decodeHistogram(histogram);
  List<int?> get perMinute => decodeCurve(curve);

  @override
  bool operator ==(Object other) =>
      other is SessionHeartRate &&
      other.sessionId == sessionId &&
      other.avgBpm == avgBpm &&
      other.maxBpm == maxBpm &&
      other.minBpm == minBpm &&
      other.seconds == seconds &&
      other.histogram == histogram &&
      other.curve == curve &&
      other.recoveryBpm == recoveryBpm;

  @override
  int get hashCode => Object.hash(
    sessionId,
    avgBpm,
    maxBpm,
    minBpm,
    seconds,
    histogram,
    curve,
    recoveryBpm,
  );
}
