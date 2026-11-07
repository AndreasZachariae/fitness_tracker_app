import '../../domain/models/models.dart';
import '../../domain/records.dart';
import '../../domain/weight_steps.dart';
import '../l10n/strings_de.dart';
import 'formatters.dart';

/// Duration for targets and summaries: `45 s`, `1:30 min`.
String formatDuration(int seconds) => seconds < 60
    ? '$seconds ${S.secondsUnit}'
    : '${formatMinSec(Duration(seconds: seconds))} ${S.minutesUnit}';

/// A level: `10`, `8,9` for an old kg value between two levels (1.1.0).
String formatLevel(double level) {
  final r = level.roundToDouble();
  return (level - r).abs() < 0.05 ? '${r.toInt()}' : formatDecimal1(level);
}

/// A stored weight with [levels]: `Stufe 10 (45 kg)`, `Stufe 10` (levels
/// without kg); without levels `45 kg` (1.1.0).
String formatLoad(double weight, LevelStep? levels) {
  if (levels == null) return formatKg(weight);
  final level = '${S.level} ${formatLevel(levels.levelOf(weight))}';
  return levels.kgPerLevel == null ? level : '$level (${formatKg(weight)})';
}

/// Added weight of bodyweight exercises: `+0 kg`, `+10 kg`, `−20 kg`.
String formatSignedKg(double kg) {
  final sign = kg < 0 ? '−' : '+';
  return '$sign${formatKg(kg.abs())}';
}

/// Target of an exercise in a plan or session: `3 × 10`, `3 × 45 s`,
/// `3 Sätze` (without reps/duration target).
String formatTarget(
  ExerciseType type, {
  required int sets,
  int? reps,
  int? durationSec,
}) {
  final per = type == ExerciseType.timed
      ? (durationSec == null ? null : formatDuration(durationSec))
      : reps?.toString();
  return per == null ? S.sets(sets) : '$sets × $per';
}

/// Compact summary of sets, e.g. `60 kg × 10, 10, 8` (same weight),
/// `60 × 10, 62,5 × 8` (changing weight), `10, 9, 8 Wdh` (bodyweight
/// without added weight), `45, 45, 40 s` (timed).
///
/// With [levels] (1.1.0): `Stufe 10 (45 kg) × 10, 10` or `Stufe 10 × 10,
/// 11 × 8`.
String formatSetsSummary(
  ExerciseType type,
  List<SetEntry> sets, {
  LevelStep? levels,
}) {
  if (sets.isEmpty) return '';
  switch (type) {
    case ExerciseType.weightReps when levels != null:
      final weights = sets.map((s) => s.weightKg ?? 0).toSet();
      if (weights.length == 1) {
        return '${formatLoad(weights.single, levels)} × '
            '${sets.map((s) => s.reps ?? 0).join(', ')}';
      }
      return _levelPairs(sets, levels);
    case ExerciseType.weightReps:
      final weights = sets.map((s) => s.weightKg ?? 0).toSet();
      if (weights.length == 1) {
        return '${formatKg(weights.single)} × '
            '${sets.map((s) => s.reps ?? 0).join(', ')}';
      }
      return sets
          .map((s) => '${formatWeight(s.weightKg ?? 0)} × ${s.reps ?? 0}')
          .join(', ');
    case ExerciseType.bodyweight:
      final weights = sets.map((s) => s.weightKg ?? 0).toSet();
      final reps = sets.map((s) => s.reps ?? 0);
      if (weights.length == 1 && weights.single == 0) {
        return '${reps.join(', ')} ${S.repsUnit}';
      }
      if (weights.length == 1) {
        return '${formatSignedKg(weights.single)} × ${reps.join(', ')}';
      }
      return sets
          .map(
            (s) =>
                '${formatSignedKg(s.weightKg ?? 0).replaceAll(' ${S.unitKg}', '')}'
                ' × ${s.reps ?? 0}',
          )
          .join(', ');
    case ExerciseType.timed:
      final durations = sets.map((s) => s.durationSec ?? 0).toList();
      if (durations.every((d) => d < 60)) {
        return '${durations.join(', ')} ${S.secondsUnit}';
      }
      return '${durations.map((d) => formatMinSec(Duration(seconds: d))).join(', ')} '
          '${S.minutesUnit}';
  }
}

/// `Stufe 10 × 10, 11 × 8`.
String _levelPairs(List<SetEntry> sets, LevelStep levels) =>
    '${S.level} ${sets.map((s) => '${formatLevel(levels.levelOf(s.weightKg ?? 0))} × ${s.reps ?? 0}').join(', ')}';

/// One set: `60 kg × 10`, `10 Wdh`, `+10 kg × 8`, `45 s`, `1:30 min · +5 kg`;
/// with [levels] `Stufe 10 (45 kg) × 10`.
String formatSingleSet(ExerciseType type, SetEntry set, {LevelStep? levels}) {
  final w = set.weightKg ?? 0;
  return switch (type) {
    ExerciseType.weightReps => '${formatLoad(w, levels)} × ${set.reps ?? 0}',
    ExerciseType.bodyweight =>
      w == 0
          ? '${set.reps ?? 0} ${S.repsUnit}'
          : '${formatSignedKg(w)} × ${set.reps ?? 0}',
    ExerciseType.timed =>
      formatDuration(set.durationSec ?? 0) +
          (w > 0 ? ' · ${formatSignedKg(w)}' : ''),
  };
}

/// Sets for "Letztes Mal (28.10.): 60 × 10, 60 × 10, 60 × 8"; with
/// [levels] `Stufe 10 × 10, 10 × 10, 11 × 8`.
String formatSetsDetailed(
  ExerciseType type,
  List<SetEntry> sets, {
  LevelStep? levels,
}) {
  switch (type) {
    case ExerciseType.weightReps when levels != null:
      return _levelPairs(sets, levels);
    case ExerciseType.weightReps:
      return sets
          .map((s) => '${formatWeight(s.weightKg ?? 0)} × ${s.reps ?? 0}')
          .join(', ');
    case ExerciseType.bodyweight:
    case ExerciseType.timed:
      return formatSetsSummary(type, sets);
  }
}

/// Value of a record: `82,5 kg`, `12 Wdh`, `+10 kg`, `1:30 min`; for levels
/// without kg `Stufe 12` (1.1.0).
String formatRecordValue(RecordKind kind, double value, {LevelStep? levels}) =>
    switch (kind) {
      RecordKind.estimatedOneRepMax || RecordKind.weight
          when levels != null && levels.kgPerLevel == null =>
        '${S.level} ${formatLevel(value)}',
      RecordKind.estimatedOneRepMax ||
      RecordKind.weight => formatKg((value * 10).round() / 10),
      RecordKind.reps => '${value.round()} ${S.repsUnit}',
      RecordKind.addedWeight => formatSignedKg(value),
      RecordKind.duration => formatDuration(value.round()),
    };
