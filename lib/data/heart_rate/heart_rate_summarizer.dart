import 'package:drift/drift.dart';

import '../../domain/heart_rate.dart';
import '../../domain/heart_rate_zones.dart';
import '../../domain/models/models.dart';

// Plain SQL on purpose: also used by the migration to schema 7, which must
// not depend on later versions of the generated tables.

DateTime _time(Object? value) => switch (value) {
  final String s => DateTime.parse(s).toUtc(),
  final int ms => DateTime.fromMillisecondsSinceEpoch(ms * 1000, isUtc: true),
  _ => throw ArgumentError.value(value, 'time'),
};

/// Turns the buffered heart rate of a finished training into what is kept
/// (1.5.1): set, exercise and training summaries; then empties the buffer.
/// Without samples nothing happens. [schema8]: also the heart rate recovery
/// and the time in the warm-up target (1.6.0, zones after the threshold
/// since 1.6.1); false only in the migration to schema 7, before those
/// columns exist.
Future<void> summarizeSessionHeartRate(
  DatabaseConnectionUser db,
  int sessionId, {
  bool schema8 = true,
}) async {
  final session = await db
      .customSelect(
        'SELECT started_at, ended_at FROM sessions WHERE id = ?',
        variables: [Variable.withInt(sessionId)],
      )
      .getSingleOrNull();
  if (session == null) return;
  final start = _time(session.data['started_at']);
  final endValue = session.data['ended_at'];
  final end = endValue == null ? null : _time(endValue);
  final samples = [
    for (final row
        in await db
            .customSelect(
              'SELECT id, recorded_at, bpm FROM heart_rate_samples '
              'WHERE session_id = ? ORDER BY recorded_at',
              variables: [Variable.withInt(sessionId)],
            )
            .get())
      HeartRateSample(
        id: row.read<int>('id'),
        sessionId: sessionId,
        recordedAt: _time(row.data['recorded_at']),
        bpm: row.read<int>('bpm'),
      ),
  ].where((s) => end == null || !s.recordedAt.isAfter(end)).toList();
  if (samples.isNotEmpty) {
    // Heart rate profile and warm-up targets (1.6.0).
    int? threshold;
    final targets = <int, ({int? zone, int? bpm})>{};
    if (schema8) {
      threshold =
          (await db
                  .customSelect('SELECT hr_threshold FROM app_settings LIMIT 1')
                  .getSingleOrNull())
              ?.readNullable<int>('hr_threshold');
      for (final row
          in await db
              .customSelect(
                'SELECT se.id, e.hr_target_range, e.hr_target_bpm '
                'FROM session_exercises se JOIN exercises e '
                'ON e.id = se.exercise_id WHERE se.session_id = ? '
                "AND e.type = 'timed' AND e.hr_target_minutes IS NOT NULL",
                variables: [Variable.withInt(sessionId)],
              )
              .get()) {
        final zone = row.readNullable<int>('hr_target_range');
        final bpm = row.readNullable<int>('hr_target_bpm');
        if (zone != null || bpm != null) {
          targets[row.read<int>('id')] = (zone: zone, bpm: bpm);
        }
      }
    }
    final allWindows = <SetWindow>[];
    // Sets per exercise.
    final bySessionExercise = <int, List<SetEntry>>{};
    for (final row
        in await db
            .customSelect(
              'SELECT s.id, s.session_exercise_id, s.set_index, s.completed_at, '
              's.duration_sec FROM set_entries s JOIN session_exercises se '
              'ON se.id = s.session_exercise_id WHERE se.session_id = ?',
              variables: [Variable.withInt(sessionId)],
            )
            .get()) {
      final seId = row.read<int>('session_exercise_id');
      bySessionExercise
          .putIfAbsent(seId, () => [])
          .add(
            SetEntry(
              id: row.read<int>('id'),
              sessionExerciseId: seId,
              setIndex: row.read<int>('set_index'),
              weightKg: null,
              reps: null,
              durationSec: row.readNullable<int>('duration_sec'),
              isWarmup: false,
              completedAt: _time(row.data['completed_at']),
            ),
          );
    }
    for (final MapEntry(key: seId, value: sets) in bySessionExercise.entries) {
      final sorted = [...sets]
        ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
      final windows = setWindows(sorted);
      allWindows.addAll(windows);
      final target = targets[seId];
      for (var i = 0; i < sorted.length; i++) {
        final hr = setHeartRate(samples, windows[i]);
        await db.customStatement(
          'UPDATE set_entries SET hr_avg = ?, hr_peak = ? WHERE id = ?',
          [hr?.average, hr?.peak, sorted[i].id],
        );
        if (target != null && sorted[i].durationSec != null) {
          final end = sorted[i].completedAt;
          await db.customStatement(
            'UPDATE set_entries SET hr_target_sec = ? WHERE id = ?',
            [
              secondsInTarget(
                samples,
                from: end.subtract(Duration(seconds: sorted[i].durationSec!)),
                to: end,
                zone: target.zone,
                targetBpm: target.bpm,
                threshold: threshold,
              ),
              sorted[i].id,
            ],
          );
        }
      }
      final ex = exerciseHeartRate(samples, sorted);
      await db.customStatement(
        'UPDATE session_exercises SET hr_avg = ?, hr_max = ? WHERE id = ?',
        [ex?.average, ex?.max, seId],
      );
    }
    final summary = summarizeHeartRate(samples, start);
    if (summary != null) {
      await db.customStatement(
        'INSERT OR REPLACE INTO session_heart_rates (session_id, avg_bpm, '
        'max_bpm, min_bpm, seconds, histogram, curve) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          sessionId,
          summary.average,
          summary.max,
          summary.min,
          summary.seconds,
          encodeHistogram(summary.histogram),
          encodeCurve(summary.curve),
        ],
      );
      if (schema8) {
        await db.customStatement(
          'UPDATE session_heart_rates SET recovery_bpm = ? WHERE session_id = ?',
          [
            heartRateRecovery(samples, allWindows, threshold: threshold),
            sessionId,
          ],
        );
      }
    }
  }
  await db.customStatement(
    'DELETE FROM heart_rate_samples WHERE session_id = ?',
    [sessionId],
  );
}

/// [summarizeSessionHeartRate] for every finished training that still has
/// a series (the 1.5.0 data, migration to schema 7).
Future<void> summarizeFinishedHeartRates(
  DatabaseConnectionUser db, {
  bool schema8 = true,
}) async {
  final rows = await db
      .customSelect(
        'SELECT DISTINCT h.session_id AS id FROM heart_rate_samples h '
        'JOIN sessions s ON s.id = h.session_id WHERE s.ended_at IS NOT NULL',
      )
      .get();
  for (final row in rows) {
    await summarizeSessionHeartRate(db, row.read<int>('id'), schema8: schema8);
  }
}
