/// Import of a workout shared as text from "FitNotes Gym Workout Log"
/// (1.4.0). Pure Dart: reads the text, recognises exercise types, targets and
/// groups, and suggests matching GymLog exercises.
library;

import 'models/models.dart';
import 'names.dart';
import 'weight_steps.dart';

/// One set of the export.
typedef FitNotesSet = ({double? weightKg, int? reps, int? durationSec});

/// One exercise of the export with its sets (sets with 0 reps left out).
final class FitNotesExercise {
  const FitNotesExercise({
    required this.name,
    required this.type,
    required this.sets,
    this.group,
  });

  /// Name as in FitNotes, whitespace cleaned.
  final String name;

  /// The free text in brackets after the name, e.g. "Monday Core Set".
  final String? group;
  final ExerciseType type;
  final List<FitNotesSet> sets;

  /// Supersets ("Set") and rotations ("Rotate") are marked by the user's
  /// own group names in FitNotes, which only knows supersets (decided by the
  /// user).
  PlanGroupKind? get groupKind => groupKindOf(group);

  /// Targets for the plan: number of sets and the most frequent reps or
  /// duration (ties: the earlier one).
  int get targetSets => sets.length;
  int? get targetReps => type == ExerciseType.timed
      ? null
      : _mostFrequent([for (final s in sets) ?s.reps]);
  int? get targetDurationSec => type == ExerciseType.timed
      ? _mostFrequent([for (final s in sets) ?s.durationSec])
      : null;

  /// Most frequent weight, for the preview.
  double? get typicalWeightKg => _mostFrequent([
    for (final s in sets)
      if (s.weightKg case final w? when w > 0) w,
  ]);
}

/// A workout read from the export.
final class FitNotesWorkout {
  const FitNotesWorkout({
    required this.exercises,
    this.date,
    this.dayLabel,
    this.skippedSets = 0,
    this.unreadLines = const [],
  });

  /// Day of the workout from the first line; null if it was not readable.
  final LocalDate? date;

  /// The weekday word of the first line, e.g. "Montag" (a plan name).
  final String? dayLabel;
  final List<FitNotesExercise> exercises;

  /// Sets with 0 reps, left out (decided by the user).
  final int skippedSets;

  /// Lines that are neither an exercise nor a set GymLog understands.
  final List<String> unreadLines;

  int get setCount => exercises.fold(0, (n, e) => n + e.sets.length);
}

/// The text is not a FitNotes workout export.
final class FitNotesFormatException implements Exception {
  const FitNotesFormatException(this.message);

  final String message;

  @override
  String toString() => 'FitNotesFormatException: $message';
}

PlanGroupKind? groupKindOf(String? group) {
  if (group == null) return null;
  if (RegExp(r'rotat', caseSensitive: false).hasMatch(group)) {
    return PlanGroupKind.rotation;
  }
  if (RegExp(r'\bset\b', caseSensitive: false).hasMatch(group)) {
    return PlanGroupKind.superset;
  }
  return null;
}

const _lbsToKg = 0.45359237;

final _header = RegExp(r'^FitNotes Workout\s*-\s*(.*)$', caseSensitive: false);
final _exercise = RegExp(r'^\*\*\s*(.+?)\s*\*\*\s*(?:\((.*)\))?\s*$');
const _weight = r'(\d+(?:[.,]\d+)?)\s*(kgs?|lbs?)';
const _time = r'(\d+):(\d{2})(?::(\d{2}))?';
final _weightReps = RegExp(
  '^$_weight\\s*x\\s*(\\d+)\\s*reps?\\b',
  caseSensitive: false,
);
final _weightTime = RegExp('^$_weight\\s*x\\s*$_time', caseSensitive: false);
final _repsOnly = RegExp(r'^(\d+)\s*reps?\b', caseSensitive: false);
final _timeOnly = RegExp('^$_time');

const _months = {
  'january': 1,
  'januar': 1,
  'jan': 1,
  'february': 2,
  'februar': 2,
  'feb': 2,
  'march': 3,
  'märz': 3,
  'mar': 3,
  'mär': 3,
  'april': 4,
  'apr': 4,
  'may': 5,
  'mai': 5,
  'june': 6,
  'juni': 6,
  'jun': 6,
  'july': 7,
  'juli': 7,
  'jul': 7,
  'august': 8,
  'aug': 8,
  'september': 9,
  'sep': 9,
  'sept': 9,
  'october': 10,
  'oktober': 10,
  'oct': 10,
  'okt': 10,
  'november': 11,
  'nov': 11,
  'december': 12,
  'dezember': 12,
  'dec': 12,
  'dez': 12,
};

/// "Montag 2nd November 2026", "Monday, 2 November 2026", "2. November 2026".
(LocalDate?, String?) _parseHeaderDate(String text) {
  final m = RegExp(
    r'(\d{1,2})(?:st|nd|rd|th|\.)?\s+([A-Za-zÄÖÜäöü]+)\.?,?\s+(\d{4})',
  ).firstMatch(text);
  LocalDate? date;
  if (m != null) {
    final month = _months[m.group(2)!.toLowerCase()];
    if (month != null) {
      try {
        date = LocalDate(int.parse(m.group(3)!), month, int.parse(m.group(1)!));
      } on ArgumentError {
        date = null;
      }
    }
  }
  final label = text.split(RegExp(r'[\s,]+')).first.trim();
  final dayLabel = label.isEmpty || RegExp(r'\d').hasMatch(label)
      ? null
      : label;
  return (date, dayLabel);
}

double _number(String s) => double.parse(s.replaceAll(',', '.'));

double _kg(String value, String unit) {
  final v = _number(value);
  final kg = unit.toLowerCase().startsWith('lb') ? v * _lbsToKg : v;
  return (kg * 100).round() / 100;
}

int _seconds(Match m, int first) {
  final a = int.parse(m.group(first)!);
  final b = int.parse(m.group(first + 1)!);
  final c = m.group(first + 2);
  // mm:ss, or h:mm:ss.
  return c == null ? a * 60 + b : a * 3600 + b * 60 + int.parse(c);
}

/// Reads the text of "Share workout" from FitNotes.
///
/// Throws [FitNotesFormatException] if it is not such an export or holds
/// more than one workout.
FitNotesWorkout parseFitNotes(String text) {
  final lines = text
      .replaceAll('\r', '')
      .replaceFirst('﻿', '')
      .split('\n')
      .map((l) => l.trim())
      .toList();
  LocalDate? date;
  String? dayLabel;
  var headers = 0;
  var skipped = 0;
  final unread = <String>[];
  final names = <String>[];
  final groups = <String, String?>{};
  final sets = <String, List<FitNotesSet>>{};
  final keys = <String, String>{};
  String? current;

  for (final line in lines) {
    if (line.isEmpty) continue;
    if (_header.firstMatch(line) case final h?) {
      headers++;
      (date, dayLabel) = _parseHeaderDate(h.group(1)!);
      continue;
    }
    if (_exercise.firstMatch(line) case final e?) {
      final name = cleanName(e.group(1)!);
      final key = nameKey(name);
      // The same exercise twice: one exercise with all sets.
      if (!keys.containsKey(key)) {
        keys[key] = name;
        names.add(name);
        sets[name] = [];
        final group = e.group(2)?.trim();
        groups[name] = group == null || group.isEmpty ? null : group;
      }
      current = keys[key];
      continue;
    }
    if (line.startsWith('-') && current != null) {
      final value = line.substring(1).trim();
      FitNotesSet? set;
      if (_weightReps.firstMatch(value) case final m?) {
        final reps = int.parse(m.group(3)!);
        if (reps == 0) {
          skipped++;
          continue;
        }
        set = (
          weightKg: _kg(m.group(1)!, m.group(2)!),
          reps: reps,
          durationSec: null,
        );
      } else if (_weightTime.firstMatch(value) case final m?) {
        set = (
          weightKg: _kg(m.group(1)!, m.group(2)!),
          reps: null,
          durationSec: _seconds(m, 3),
        );
      } else if (_repsOnly.firstMatch(value) case final m?) {
        final reps = int.parse(m.group(1)!);
        if (reps == 0) {
          skipped++;
          continue;
        }
        set = (weightKg: null, reps: reps, durationSec: null);
      } else if (_timeOnly.firstMatch(value) case final m?) {
        set = (weightKg: null, reps: null, durationSec: _seconds(m, 1));
      }
      if (set == null || (set.durationSec != null && set.durationSec! <= 0)) {
        unread.add(line);
      } else {
        sets[current]!.add(set);
      }
      continue;
    }
    unread.add(line);
  }

  if (headers == 0) {
    throw const FitNotesFormatException('no FitNotes header');
  }
  if (headers > 1) {
    throw const FitNotesFormatException('more than one workout');
  }
  final exercises = <FitNotesExercise>[
    for (final name in names)
      if (sets[name]!.isNotEmpty)
        FitNotesExercise(
          name: name,
          group: groups[name],
          type: _typeOf(sets[name]!),
          sets: _fit(_typeOf(sets[name]!), sets[name]!),
        ),
  ];
  if (exercises.isEmpty) {
    throw const FitNotesFormatException('no exercises with sets');
  }
  return FitNotesWorkout(
    exercises: exercises,
    date: date,
    dayLabel: dayLabel,
    skippedSets: skipped,
    unreadLines: unread,
  );
}

/// Time → timed; a weight → weight × reps; only reps → bodyweight.
ExerciseType _typeOf(List<FitNotesSet> sets) {
  if (sets.any((s) => s.durationSec != null)) return ExerciseType.timed;
  if (sets.any((s) => s.weightKg != null)) return ExerciseType.weightReps;
  return ExerciseType.bodyweight;
}

/// Sets that do not fit the type of the exercise (mixed lines) are dropped:
/// a timed exercise keeps its timed sets, a weight exercise its weight sets.
List<FitNotesSet> _fit(ExerciseType type, List<FitNotesSet> sets) => [
  for (final s in sets)
    if (switch (type) {
      ExerciseType.timed => s.durationSec != null,
      ExerciseType.weightReps => s.weightKg != null && s.reps != null,
      ExerciseType.bodyweight => s.reps != null,
    })
      s,
];

T? _mostFrequent<T>(List<T> values) {
  if (values.isEmpty) return null;
  final count = <T, int>{};
  for (final v in values) {
    count[v] = (count[v] ?? 0) + 1;
  }
  var best = values.first;
  for (final v in values) {
    if (count[v]! > count[best]!) best = v;
  }
  return best;
}

/// Whether the sets of [source] can be stored for [exercise]: same type, or
/// weight × reps as added weight of a bodyweight exercise; weights only for
/// exercises that store kg (not levels without kg).
bool canImportInto(FitNotesExercise source, Exercise exercise) {
  if (exercise.archived) return false;
  final typeFits =
      source.type == exercise.type ||
      (source.type == ExerciseType.weightReps &&
          exercise.type == ExerciseType.bodyweight);
  if (!typeFits) return false;
  final hasWeight = source.sets.any((s) => (s.weightKg ?? 0) != 0);
  return !hasWeight || storesKg(exercise);
}

/// Common FitNotes names → exercises of the GymLog library (1.4.0).
const fitNotesAliases = <String, String>{
  'flat barbell bench press': 'Bankdrücken',
  'barbell bench press': 'Bankdrücken',
  'bench press': 'Bankdrücken',
  'incline barbell bench press': 'Schrägbankdrücken',
  'decline barbell bench press': 'Negativbankdrücken',
  'flat dumbbell bench press': 'Kurzhantel-Bankdrücken',
  'incline dumbbell bench press': 'Kurzhantel-Schrägbankdrücken',
  'flat dumbbell fly': 'Kurzhantel-Fliegende',
  'dumbbell fly': 'Kurzhantel-Fliegende',
  'cable crossover': 'Cable Crossover',
  'chest press machine': 'Brustpresse (Maschine)',
  'pec deck': 'Butterfly (Maschine)',
  'parallel bar triceps dip': 'Dips',
  'dips': 'Dips',
  'push up': 'Liegestütze',
  'push-up': 'Liegestütze',
  'deadlift': 'Kreuzheben',
  'barbell deadlift': 'Kreuzheben',
  'romanian deadlift': 'Rumänisches Kreuzheben',
  'pull up': 'Klimmzüge',
  'pull-up': 'Klimmzüge',
  'chin up': 'Klimmzüge im Untergriff',
  'chin-up': 'Klimmzüge im Untergriff',
  'lat pulldown': 'Latzug',
  'lat pull down': 'Latzug',
  'seated cable row': 'Rudern am Kabel (sitzend)',
  'barbell row': 'Langhantelrudern',
  'bent over row': 'Langhantelrudern',
  'one arm dumbbell row': 'Kurzhantelrudern einarmig',
  'one-arm dumbbell row': 'Kurzhantelrudern einarmig',
  't-bar row': 'T-Bar-Rudern',
  'back extension': 'Rückenstrecker',
  'hyperextension': 'Rückenstrecker',
  'barbell squat': 'Kniebeugen',
  'squat': 'Kniebeugen',
  'front squat': 'Frontkniebeugen',
  'goblet squat': 'Goblet Squats',
  'leg press': 'Beinpresse',
  'hack squat': 'Hackenschmidt-Kniebeugen',
  'leg extension machine': 'Beinstrecker (Maschine)',
  'leg extension': 'Beinstrecker (Maschine)',
  'lying leg curl machine': 'Beinbeuger liegend (Maschine)',
  'seated leg curl machine': 'Beinbeuger sitzend (Maschine)',
  'bulgarian split squat': 'Bulgarian Split Squats',
  'hip thrust': 'Hip Thrust',
  'barbell hip thrust': 'Hip Thrust',
  'standing calf raise machine': 'Wadenheben stehend (Maschine)',
  'seated calf raise machine': 'Wadenheben sitzend (Maschine)',
  'overhead press': 'Schulterdrücken (Langhantel)',
  'overhead barbell press': 'Schulterdrücken (Langhantel)',
  'seated dumbbell press': 'Kurzhantel-Schulterdrücken',
  'arnold dumbbell press': 'Arnold Press',
  'lateral dumbbell raise': 'Seitheben (Kurzhantel)',
  'lateral raise': 'Seitheben (Kurzhantel)',
  'cable lateral raise': 'Seitheben am Kabel',
  'front dumbbell raise': 'Frontheben (Kurzhantel)',
  'face pull': 'Face Pulls',
  'face pulls': 'Face Pulls',
  'upright row': 'Aufrechtes Rudern',
  'barbell curl': 'Langhantel-Curls',
  'ez-bar curl': 'SZ-Curls',
  'ez bar curl': 'SZ-Curls',
  'dumbbell curl': 'Kurzhantel-Curls',
  'hammer curl': 'Hammer Curls',
  'concentration curl': 'Konzentrationscurls',
  'close grip barbell bench press': 'Enges Bankdrücken',
  'plank': 'Plank',
  'side plank': 'Seitstütz',
  'crunch': 'Crunches',
  'crunches': 'Crunches',
  'cable crunch': 'Crunches am Kabel',
  'hanging leg raise': 'Hängendes Beinheben',
  'russian twist': 'Russian Twists',
  'ab wheel rollout': 'Bauchroller',
  'kettlebell swing': 'Kettlebell Swings',
};

/// The GymLog exercise suggested for [source]: same name, else the library
/// exercise of [fitNotesAliases]; only if the sets fit it.
Exercise? suggestExercise(FitNotesExercise source, List<Exercise> exercises) {
  Exercise? byName(String name) {
    final key = nameKey(name);
    for (final e in exercises) {
      if (nameKey(e.name) == key && canImportInto(source, e)) return e;
    }
    return null;
  }

  return byName(source.name) ??
      switch (fitNotesAliases[nameKey(source.name)]) {
        final alias? => byName(alias),
        null => null,
      };
}

/// Category of a new exercise from words of its English or German name;
/// null if nothing fits.
ExerciseCategory? guessCategory(String name) {
  final n = name.toLowerCase();
  bool any(List<String> words) => words.any(n.contains);
  if (any([
    'crunch',
    'plank',
    'sit-up',
    'sit up',
    'leg raise',
    'ab ',
    'core',
    'twist',
    'bauch',
  ])) {
    return ExerciseCategory.core;
  }
  if (any([
    'tricep',
    'bicep',
    'curl',
    'trizeps',
    'bizeps',
    'push down',
    'pushdown',
    'skull',
  ])) {
    return ExerciseCategory.arms;
  }
  if (any([
    'bench',
    'chest',
    'fly',
    'flys',
    'fly\'s',
    'push up',
    'pushup',
    'dip',
    'brust',
    'bankdrück',
  ])) {
    return n.contains('back fly') || n.contains('reverse fly')
        ? ExerciseCategory.shoulders
        : ExerciseCategory.chest;
  }
  if (any([
    'shoulder',
    'lateral',
    'face pull',
    'overhead',
    'military',
    'schulter',
    'seitheben',
  ])) {
    return ExerciseCategory.shoulders;
  }
  if (any([
    'squat',
    'leg',
    'lunge',
    'hip thrust',
    'calf',
    'glute',
    'bein',
    'waden',
    'deadlift',
  ])) {
    return ExerciseCategory.legs;
  }
  if (any([
    'row',
    'pull',
    'lat ',
    'lat',
    'back',
    'rücken',
    'rudern',
    'klimmz',
  ])) {
    return ExerciseCategory.back;
  }
  return null;
}
