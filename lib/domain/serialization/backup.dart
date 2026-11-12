import 'dart:convert';

import '../legacy_steps.dart';
import '../models/models.dart';
import '../names.dart';
import 'csv.dart' show isoWithOffset;

/// JSON backup (SPEC §8.2). All columns of all tables, ids are kept.
const backupFormat = 'gymlog-backup';

/// 2 (M9): `planGroups`, `sessionSupersets`, `planExercises[].groupId` and
/// `sessionExercises[].supersetId`. Version 1 files are still read.
/// 3 (1.1.0): weight steps. 4 (1.2.0): training days, notifications.
/// 5 (1.3.0): `exercises[].timerCountdown`. 6 (1.5.0): `heartRateSamples`.
/// 7 (1.5.1): `sessionHeartRates`, heart rate of sets and session exercises.
/// 8 (1.6.0): heart rate profile, pause by heart rate, warm-up targets,
/// time in target, heart rate recovery.
const backupFormatVersion = 8;

final class BackupData {
  const BackupData({
    required this.dataset,
    required this.settings,
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
  });

  final Dataset dataset;
  final AppSettings settings;
  final int schemaVersion;
  final String appVersion;
  final DateTime exportedAt;
}

/// Why a backup file cannot be imported.
enum BackupError {
  /// Not JSON or not an object.
  notJson,

  /// `format` is not "gymlog-backup".
  wrongFormat,

  /// Written by a newer app version (`formatVersion` too high).
  newerVersion,

  /// A required field is missing or has the wrong type.
  invalidField,

  /// A reference points to a missing row.
  brokenReference,

  /// The same id appears twice, or names collide.
  duplicate,

  /// More than one running session.
  severalActiveSessions,
}

final class BackupFormatException implements Exception {
  const BackupFormatException(this.error, [this.detail]);

  final BackupError error;
  final String? detail;

  @override
  String toString() => 'BackupFormatException(${error.name}, $detail)';
}

/// Contents of a backup for the confirmation dialog (SPEC §8.3).
final class ImportPreview {
  const ImportPreview({
    required this.trainings,
    required this.first,
    required this.last,
    required this.bodyWeights,
  });

  /// Finished sessions.
  final int trainings;
  final DateTime? first;
  final DateTime? last;
  final int bodyWeights;
}

ImportPreview previewOf(Dataset data) {
  final finished = data.sessions.where((s) => !s.isActive).toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  return ImportPreview(
    trainings: finished.length,
    first: finished.isEmpty ? null : finished.first.startedAt,
    last: finished.isEmpty ? null : finished.last.startedAt,
    bodyWeights: data.bodyWeights.length,
  );
}

// ---------------------------------------------------------------------------
// Encoding

String _t(DateTime t) => t.toUtc().toIso8601String();
String? _tn(DateTime? t) => t == null ? null : _t(t);

String encodeBackup(BackupData b) {
  final d = b.dataset;
  final s = b.settings;
  return const JsonEncoder.withIndent('  ').convert({
    'format': backupFormat,
    'formatVersion': backupFormatVersion,
    'schemaVersion': b.schemaVersion,
    'appVersion': b.appVersion,
    'exportedAt': isoWithOffset(b.exportedAt),
    'data': {
      'exercises': [
        for (final e in d.exercises)
          {
            'id': e.id,
            'name': e.name,
            'type': e.type.code,
            'category': e.category?.code,
            'incrementKg': e.incrementKg,
            'restSec': e.restSec,
            'includeInStrengthIndex': e.includeInStrengthIndex,
            'notes': e.notes,
            'archived': e.archived,
            'createdAt': _t(e.createdAt),
            'stepMode': e.stepMode.code,
            'incrementLbs': e.incrementLbs,
            'levelKg': e.levelKg,
            'timerCountdown': e.timerCountdown,
            'restByHeartRate': e.restByHeartRate,
            'hrTargetRange': e.hrTargetRange,
            'hrTargetBpm': e.hrTargetBpm,
            'hrTargetMinutes': e.hrTargetMinutes,
          },
      ],
      'plans': [
        for (final p in d.plans)
          {
            'id': p.id,
            'name': p.name,
            'position': p.position,
            'createdAt': _t(p.createdAt),
            'active': p.active,
          },
      ],
      'planSchedules': [
        for (final s in d.planSchedules)
          {
            'id': s.id,
            'planId': s.planId,
            'weekday': s.weekday,
            'minuteOfDay': s.minuteOfDay,
          },
      ],
      'planExercises': [
        for (final p in d.planExercises)
          {
            'id': p.id,
            'planId': p.planId,
            'exerciseId': p.exerciseId,
            'position': p.position,
            'targetSets': p.targetSets,
            'targetReps': p.targetReps,
            'targetDurationSec': p.targetDurationSec,
            'restSec': p.restSec,
            'groupId': p.groupId,
          },
      ],
      'planGroups': [
        for (final g in d.planGroups)
          {
            'id': g.id,
            'planId': g.planId,
            'kind': g.kind.code,
            'restSec': g.restSec,
            'rotationEvery': g.rotationEvery,
            'rotationExerciseId': g.rotationExerciseId,
            'rotationDone': g.rotationDone,
          },
      ],
      'sessions': [
        for (final x in d.sessions)
          {
            'id': x.id,
            'planId': x.planId,
            'planNameSnapshot': x.planNameSnapshot,
            'startedAt': _t(x.startedAt),
            'endedAt': _tn(x.endedAt),
            'notes': x.notes,
          },
      ],
      'sessionExercises': [
        for (final x in d.sessionExercises)
          {
            'id': x.id,
            'sessionId': x.sessionId,
            'exerciseId': x.exerciseId,
            'position': x.position,
            'targetSets': x.targetSets,
            'targetReps': x.targetReps,
            'targetDurationSec': x.targetDurationSec,
            'restSec': x.restSec,
            'status': x.status.code,
            'completedAt': _tn(x.completedAt),
            'supersetId': x.supersetId,
            'hrAvg': x.hrAvg,
            'hrMax': x.hrMax,
          },
      ],
      'sessionSupersets': [
        for (final x in d.sessionSupersets)
          {'id': x.id, 'sessionId': x.sessionId, 'restSec': x.restSec},
      ],
      'sets': [
        for (final x in d.sets)
          {
            'id': x.id,
            'sessionExerciseId': x.sessionExerciseId,
            'setIndex': x.setIndex,
            'weightKg': x.weightKg,
            'reps': x.reps,
            'durationSec': x.durationSec,
            'isWarmup': x.isWarmup,
            'hrAvg': x.hrAvg,
            'hrPeak': x.hrPeak,
            'hrTargetSec': x.hrTargetSec,
            'completedAt': _t(x.completedAt),
          },
      ],
      'bodyWeights': [
        for (final w in d.bodyWeights)
          {
            'id': w.id,
            'date': w.date.toIsoString(),
            'weightKg': w.weightKg,
            'createdAt': _t(w.createdAt),
          },
      ],
      'sessionHeartRates': [
        for (final h in d.sessionHeartRates)
          {
            'sessionId': h.sessionId,
            'avgBpm': h.avgBpm,
            'maxBpm': h.maxBpm,
            'minBpm': h.minBpm,
            'seconds': h.seconds,
            'histogram': h.histogram,
            'curve': h.curve,
            'recoveryBpm': h.recoveryBpm,
          },
      ],
      'heartRateSamples': [
        for (final h in d.heartRateSamples)
          {
            'id': h.id,
            'sessionId': h.sessionId,
            'recordedAt': _t(h.recordedAt),
            'bpm': h.bpm,
          },
      ],
      'settings': {
        'defaultSets': s.defaultSets,
        'defaultRestSec': s.defaultRestSec,
        'restTimerEnabled': s.restTimerEnabled,
        'vibrationEnabled': s.vibrationEnabled,
        'keepScreenOn': s.keepScreenOn,
        'autoActivateNext': s.autoActivateNext,
        'themeMode': s.themeMode.code,
        'lastSelectedPlanId': s.lastSelectedPlanId,
        'lastBackupAt': _tn(s.lastBackupAt),
        'backupReminderDays': s.backupReminderDays,
        'defaultStep': s.defaultStep,
        'defaultStepUnit': s.defaultStepUnit.code,
        // Format 4 (1.2.0). Device state (permission asked, update check) is
        // not part of a backup.
        'notifyEvening': s.notifyEvening,
        'eveningMinute': s.eveningMinute,
        'notifyBefore': s.notifyBefore,
        'beforeMinutes': s.beforeMinutes,
        'notifyRest': s.notifyRest,
        'notifyOpenSession': s.notifyOpenSession,
        'notifyBackup': s.notifyBackup,
        'notifyStreak': s.notifyStreak,
        'checkUpdates': s.checkUpdates,
        'bookingUrl': s.bookingUrl,
        // Format 8 (1.6.0): heart rate profile. The chosen monitor is device
        // state and not part of a backup.
        'hrMax': s.hrMax,
        'birthYear': s.birthYear,
        'sex': s.sex?.code,
        'hrWarnBpm': s.hrWarnBpm,
        'hrPauseBpm': s.hrPauseBpm,
      },
    },
  });
}

// ---------------------------------------------------------------------------
// Decoding (strict)

typedef _Json = Map<String, Object?>;

Never _invalid(String where) =>
    throw BackupFormatException(BackupError.invalidField, where);

final class _Reader {
  _Reader(this.json, this.where);

  final _Json json;
  final String where;

  Object? _raw(String key) {
    if (!json.containsKey(key)) _invalid('$where.$key');
    return json[key];
  }

  int integer(String key) =>
      _raw(key) is int ? _raw(key)! as int : _invalid('$where.$key');

  int? intOrNull(String key) {
    final v = _raw(key);
    return v == null ? null : (v is int ? v : _invalid('$where.$key'));
  }

  double number(String key) => _raw(key) is num
      ? (_raw(key)! as num).toDouble()
      : _invalid('$where.$key');

  double? numberOrNull(String key) {
    final v = _raw(key);
    return v == null
        ? null
        : (v is num ? v.toDouble() : _invalid('$where.$key'));
  }

  String string(String key) =>
      _raw(key) is String ? _raw(key)! as String : _invalid('$where.$key');

  String? stringOrNull(String key) {
    final v = _raw(key);
    return v == null ? null : (v is String ? v : _invalid('$where.$key'));
  }

  bool boolean(String key) =>
      _raw(key) is bool ? _raw(key)! as bool : _invalid('$where.$key');

  /// UTC with millisecond precision, as stored in the database.
  DateTime time(String key) => _normalize(string(key), key);

  DateTime? timeOrNull(String key) {
    final v = stringOrNull(key);
    return v == null ? null : _normalize(v, key);
  }

  DateTime _normalize(String text, String key) {
    final t = DateTime.tryParse(text);
    if (t == null) _invalid('$where.$key');
    return DateTime.fromMillisecondsSinceEpoch(
      t.millisecondsSinceEpoch,
      isUtc: true,
    );
  }

  LocalDate date(String key) {
    try {
      return LocalDate.parse(string(key));
    } on FormatException {
      _invalid('$where.$key');
    }
  }

  T coded<T extends Coded>(String key, List<T> values) {
    try {
      return byCode(values, string(key));
    } on FormatException {
      _invalid('$where.$key');
    }
  }

  T? codedOrNull<T extends Coded>(String key, List<T> values) {
    final v = stringOrNull(key);
    if (v == null) return null;
    try {
      return byCode(values, v);
    } on FormatException {
      _invalid('$where.$key');
    }
  }
}

List<T> _list<T>(_Json data, String key, T Function(_Reader) read) {
  final raw = data[key];
  if (raw is! List) _invalid('data.$key');
  return [
    for (final (i, item) in raw.indexed)
      if (item is Map<String, Object?>)
        read(_Reader(item, '$key[$i]'))
      else
        _invalid('$key[$i]'),
  ];
}

/// Parses and validates a backup file (SPEC §8.3, step 1).
BackupData decodeBackup(String text) {
  final Object? root;
  try {
    root = jsonDecode(text);
  } on FormatException {
    throw const BackupFormatException(BackupError.notJson);
  }
  if (root is! Map<String, Object?>) {
    throw const BackupFormatException(BackupError.notJson);
  }
  if (root['format'] != backupFormat) {
    throw const BackupFormatException(BackupError.wrongFormat);
  }
  final version = root['formatVersion'];
  if (version is! int || version < 1) _invalid('formatVersion');
  if (version > backupFormatVersion) {
    throw const BackupFormatException(BackupError.newerVersion);
  }
  final head = _Reader(root, 'backup');
  final schemaVersion = head.integer('schemaVersion');
  final appVersion = head.string('appVersion');
  final exportedAt = head.time('exportedAt');
  final data = root['data'];
  if (data is! Map<String, Object?>) _invalid('data');

  final v2 = version >= 2;
  final v3 = version >= 3;
  final v4 = version >= 4;
  final v5 = version >= 5;
  final v6 = version >= 6;
  final v7 = version >= 7;
  final v8 = version >= 8;
  final dataset = Dataset(
    exercises: _list(
      data,
      'exercises',
      (r) => Exercise(
        id: r.integer('id'),
        name: r.string('name'),
        type: r.coded('type', ExerciseType.values),
        category: r.codedOrNull('category', ExerciseCategory.values),
        incrementKg: r.number('incrementKg'),
        restSec: r.intOrNull('restSec'),
        includeInStrengthIndex: r.boolean('includeInStrengthIndex'),
        notes: r.string('notes'),
        archived: r.boolean('archived'),
        createdAt: r.time('createdAt'),
        // Before format 3 (1.1.0): the same steps as the database migration.
        stepMode: v3
            ? r.coded('stepMode', StepMode.values)
            : legacyStepMode(
                r.string('name'),
                r.coded('type', ExerciseType.values),
              ),
        incrementLbs: v3
            ? r.number('incrementLbs')
            : Exercise.defaultIncrementLbs,
        levelKg: v3
            ? r.numberOrNull('levelKg')
            : legacyStepMode(
                    r.string('name'),
                    r.coded('type', ExerciseType.values),
                  ) ==
                  StepMode.levels
            ? v3LevelKg
            : null,
        timerCountdown: v5 && r.boolean('timerCountdown'),
        restByHeartRate: v8 && r.boolean('restByHeartRate'),
        hrTargetRange: v8 ? r.intOrNull('hrTargetRange') : null,
        hrTargetBpm: v8 ? r.intOrNull('hrTargetBpm') : null,
        hrTargetMinutes: v8 ? r.intOrNull('hrTargetMinutes') : null,
      ),
    ),
    plans: _list(
      data,
      'plans',
      (r) => Plan(
        id: r.integer('id'),
        name: r.string('name'),
        position: r.integer('position'),
        createdAt: r.time('createdAt'),
        active: !v4 || r.boolean('active'),
      ),
    ),
    planSchedules: !v4
        ? const []
        : _list(
            data,
            'planSchedules',
            (r) => PlanScheduleEntry(
              id: r.integer('id'),
              planId: r.integer('planId'),
              weekday: r.integer('weekday'),
              minuteOfDay: r.integer('minuteOfDay'),
            ),
          ),
    planExercises: _list(
      data,
      'planExercises',
      (r) => PlanExercise(
        id: r.integer('id'),
        planId: r.integer('planId'),
        exerciseId: r.integer('exerciseId'),
        position: r.integer('position'),
        targetSets: r.integer('targetSets'),
        targetReps: r.intOrNull('targetReps'),
        targetDurationSec: r.intOrNull('targetDurationSec'),
        restSec: r.intOrNull('restSec'),
        groupId: v2 ? r.intOrNull('groupId') : null,
      ),
    ),
    planGroups: !v2
        ? const []
        : _list(
            data,
            'planGroups',
            (r) => PlanGroup(
              id: r.integer('id'),
              planId: r.integer('planId'),
              kind: r.coded('kind', PlanGroupKind.values),
              restSec: r.intOrNull('restSec'),
              rotationEvery: r.integer('rotationEvery'),
              rotationExerciseId: r.intOrNull('rotationExerciseId'),
              rotationDone: r.integer('rotationDone'),
            ),
          ),
    sessions: _list(
      data,
      'sessions',
      (r) => Session(
        id: r.integer('id'),
        planId: r.intOrNull('planId'),
        planNameSnapshot: r.stringOrNull('planNameSnapshot'),
        startedAt: r.time('startedAt'),
        endedAt: r.timeOrNull('endedAt'),
        notes: r.string('notes'),
      ),
    ),
    sessionExercises: _list(
      data,
      'sessionExercises',
      (r) => SessionExercise(
        id: r.integer('id'),
        sessionId: r.integer('sessionId'),
        exerciseId: r.integer('exerciseId'),
        position: r.integer('position'),
        targetSets: r.integer('targetSets'),
        targetReps: r.intOrNull('targetReps'),
        targetDurationSec: r.intOrNull('targetDurationSec'),
        restSec: r.intOrNull('restSec'),
        status: r.coded('status', SessionExerciseStatus.values),
        completedAt: r.timeOrNull('completedAt'),
        supersetId: v2 ? r.intOrNull('supersetId') : null,
        hrAvg: v7 ? r.intOrNull('hrAvg') : null,
        hrMax: v7 ? r.intOrNull('hrMax') : null,
      ),
    ),
    sessionSupersets: !v2
        ? const []
        : _list(
            data,
            'sessionSupersets',
            (r) => SessionSuperset(
              id: r.integer('id'),
              sessionId: r.integer('sessionId'),
              restSec: r.intOrNull('restSec'),
            ),
          ),
    sets: _list(
      data,
      'sets',
      (r) => SetEntry(
        id: r.integer('id'),
        sessionExerciseId: r.integer('sessionExerciseId'),
        setIndex: r.integer('setIndex'),
        weightKg: r.numberOrNull('weightKg'),
        reps: r.intOrNull('reps'),
        durationSec: r.intOrNull('durationSec'),
        isWarmup: r.boolean('isWarmup'),
        hrAvg: v7 ? r.intOrNull('hrAvg') : null,
        hrPeak: v7 ? r.intOrNull('hrPeak') : null,
        hrTargetSec: v8 ? r.intOrNull('hrTargetSec') : null,
        completedAt: r.time('completedAt'),
      ),
    ),
    bodyWeights: _list(
      data,
      'bodyWeights',
      (r) => BodyWeightEntry(
        id: r.integer('id'),
        date: r.date('date'),
        weightKg: r.number('weightKg'),
        createdAt: r.time('createdAt'),
      ),
    ),
    sessionHeartRates: !v7
        ? const []
        : _list(
            data,
            'sessionHeartRates',
            (r) => SessionHeartRate(
              sessionId: r.integer('sessionId'),
              avgBpm: r.integer('avgBpm'),
              maxBpm: r.integer('maxBpm'),
              minBpm: r.integer('minBpm'),
              seconds: r.integer('seconds'),
              histogram: r.string('histogram'),
              curve: r.string('curve'),
              recoveryBpm: v8 ? r.intOrNull('recoveryBpm') : null,
            ),
          ),
    heartRateSamples: !v6
        ? const []
        : _list(
            data,
            'heartRateSamples',
            (r) => HeartRateSample(
              id: r.integer('id'),
              sessionId: r.integer('sessionId'),
              recordedAt: r.time('recordedAt'),
              bpm: r.integer('bpm'),
            ),
          ),
  );

  final rawSettings = data['settings'];
  if (rawSettings is! Map<String, Object?>) _invalid('data.settings');
  final r = _Reader(rawSettings, 'settings');
  final base = AppSettings(
    defaultSets: r.integer('defaultSets'),
    defaultRestSec: r.integer('defaultRestSec'),
    restTimerEnabled: r.boolean('restTimerEnabled'),
    vibrationEnabled: r.boolean('vibrationEnabled'),
    keepScreenOn: r.boolean('keepScreenOn'),
    autoActivateNext: r.boolean('autoActivateNext'),
    themeMode: r.coded('themeMode', ThemePreference.values),
    lastSelectedPlanId: r.intOrNull('lastSelectedPlanId'),
    lastBackupAt: r.timeOrNull('lastBackupAt'),
    backupReminderDays: r.integer('backupReminderDays'),
    defaultStep: v3
        ? r.number('defaultStep')
        : AppSettings.defaults.defaultStep,
    defaultStepUnit: v3
        ? r.coded('defaultStepUnit', WeightUnit.values)
        : AppSettings.defaults.defaultStepUnit,
  );
  final notifications = v4
      ? base.copyWith(
          notifyEvening: r.boolean('notifyEvening'),
          eveningMinute: r.integer('eveningMinute'),
          notifyBefore: r.boolean('notifyBefore'),
          beforeMinutes: r.integer('beforeMinutes'),
          notifyRest: r.boolean('notifyRest'),
          notifyOpenSession: r.boolean('notifyOpenSession'),
          notifyBackup: r.boolean('notifyBackup'),
          notifyStreak: r.boolean('notifyStreak'),
          checkUpdates: r.boolean('checkUpdates'),
          bookingUrl: r.string('bookingUrl'),
        )
      : base;
  final settings = v8
      ? notifications.copyWith(
          hrMax: r.intOrNull('hrMax'),
          birthYear: r.intOrNull('birthYear'),
          sex: r.codedOrNull('sex', Sex.values),
          hrWarnBpm: r.intOrNull('hrWarnBpm'),
          hrPauseBpm: r.intOrNull('hrPauseBpm'),
        )
      : notifications;

  validateDataset(dataset, settings);
  return BackupData(
    dataset: dataset,
    settings: settings,
    schemaVersion: schemaVersion,
    appVersion: appVersion,
    exportedAt: exportedAt,
  );
}

/// Referential integrity and uniqueness (SPEC §8.3).
void validateDataset(Dataset d, AppSettings settings) {
  Set<int> ids<T>(List<T> rows, int Function(T) id, String what) {
    final result = <int>{};
    for (final row in rows) {
      if (!result.add(id(row))) {
        throw BackupFormatException(BackupError.duplicate, '$what ${id(row)}');
      }
    }
    return result;
  }

  void unique(Iterable<Object> keys, String what) {
    final seen = <Object>{};
    for (final k in keys) {
      if (!seen.add(k)) {
        throw BackupFormatException(BackupError.duplicate, '$what $k');
      }
    }
  }

  void ref(Set<int> ids, int? id, String what) {
    if (id != null && !ids.contains(id)) {
      throw BackupFormatException(BackupError.brokenReference, '$what $id');
    }
  }

  final exercises = ids(d.exercises, (e) => e.id, 'exercise');
  final plans = ids(d.plans, (p) => p.id, 'plan');
  ids(d.planExercises, (p) => p.id, 'planExercise');
  final sessions = ids(d.sessions, (s) => s.id, 'session');
  final sessionExercises = ids(
    d.sessionExercises,
    (s) => s.id,
    'sessionExercise',
  );
  ids(d.sets, (s) => s.id, 'set');
  ids(d.bodyWeights, (b) => b.id, 'bodyWeight');
  unique(d.exercises.map((e) => nameKey(e.name)), 'exercise name');
  unique(d.plans.map((p) => nameKey(p.name)), 'plan name');
  unique(d.bodyWeights.map((b) => b.date), 'body weight date');

  final groupPlan = {for (final g in d.planGroups) g.id: g.planId};
  ids(d.planGroups, (g) => g.id, 'planGroup');
  for (final g in d.planGroups) {
    ref(plans, g.planId, 'planGroup.planId');
  }
  ids(d.planSchedules, (s) => s.id, 'planSchedule');
  for (final s in d.planSchedules) {
    ref(plans, s.planId, 'planSchedule.planId');
    if (s.weekday < 1 ||
        s.weekday > 7 ||
        s.minuteOfDay < 0 ||
        s.minuteOfDay >= 24 * 60) {
      throw BackupFormatException(
        BackupError.invalidField,
        'planSchedule ${s.id}',
      );
    }
  }
  unique(
    d.planSchedules.map((s) => (s.planId, s.weekday)),
    'plan training day',
  );
  for (final p in d.planExercises) {
    ref(plans, p.planId, 'planExercise.planId');
    ref(exercises, p.exerciseId, 'planExercise.exerciseId');
    ref(groupPlan.keys.toSet(), p.groupId, 'planExercise.groupId');
    if (p.groupId != null && groupPlan[p.groupId] != p.planId) {
      throw BackupFormatException(
        BackupError.brokenReference,
        'planExercise.groupId ${p.groupId}',
      );
    }
  }
  unique(d.planExercises.map((p) => (p.planId, p.exerciseId)), 'plan exercise');
  for (final s in d.sessions) {
    ref(plans, s.planId, 'session.planId');
  }
  final supersetSession = {
    for (final x in d.sessionSupersets) x.id: x.sessionId,
  };
  ids(d.sessionSupersets, (x) => x.id, 'sessionSuperset');
  for (final x in d.sessionSupersets) {
    ref(sessions, x.sessionId, 'sessionSuperset.sessionId');
  }
  for (final s in d.sessionExercises) {
    ref(sessions, s.sessionId, 'sessionExercise.sessionId');
    ref(exercises, s.exerciseId, 'sessionExercise.exerciseId');
    ref(
      supersetSession.keys.toSet(),
      s.supersetId,
      'sessionExercise.supersetId',
    );
    if (s.supersetId != null && supersetSession[s.supersetId] != s.sessionId) {
      throw BackupFormatException(
        BackupError.brokenReference,
        'sessionExercise.supersetId ${s.supersetId}',
      );
    }
  }
  unique(
    d.sessionExercises.map((s) => (s.sessionId, s.exerciseId)),
    'session exercise',
  );
  for (final s in d.sets) {
    ref(sessionExercises, s.sessionExerciseId, 'set.sessionExerciseId');
  }
  unique(d.sessionHeartRates.map((h) => h.sessionId), 'session heart rate');
  for (final h in d.sessionHeartRates) {
    ref(sessions, h.sessionId, 'sessionHeartRate.sessionId');
  }
  ids(d.heartRateSamples, (h) => h.id, 'heartRateSample');
  for (final h in d.heartRateSamples) {
    ref(sessions, h.sessionId, 'heartRateSample.sessionId');
    if (h.bpm < 20 || h.bpm > 255) {
      throw BackupFormatException(
        BackupError.invalidField,
        'heartRateSample ${h.id}',
      );
    }
  }
  ref(plans, settings.lastSelectedPlanId, 'settings.lastSelectedPlanId');
  if (d.sessions.where((s) => s.isActive).length > 1) {
    throw const BackupFormatException(BackupError.severalActiveSessions);
  }
}
