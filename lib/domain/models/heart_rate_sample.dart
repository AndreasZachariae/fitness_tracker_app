/// One heart rate value during a training (table `heart_rate_samples`,
/// 1.5.0): from a Bluetooth heart rate monitor, every few seconds.
final class HeartRateSample {
  const HeartRateSample({
    required this.id,
    required this.sessionId,
    required this.recordedAt,
    required this.bpm,
  });

  final int id;
  final int sessionId;

  /// UTC.
  final DateTime recordedAt;

  /// Beats per minute.
  final int bpm;

  @override
  bool operator ==(Object other) =>
      other is HeartRateSample &&
      other.id == id &&
      other.sessionId == sessionId &&
      other.recordedAt == recordedAt &&
      other.bpm == bpm;

  @override
  int get hashCode => Object.hash(id, sessionId, recordedAt, bpm);

  @override
  String toString() => 'HeartRateSample($recordedAt, $bpm)';
}
