import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/data/demo/demo_data.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/serialization/backup.dart';
import 'package:gymlog/domain/serialization/csv_export.dart';

import '../../helpers/test_db.dart';

void main() {
  final demo = generateDemoData(now: testNow);
  final settings = AppSettings.defaults.copyWith(
    defaultRestSec: 120,
    themeMode: ThemePreference.dark,
    lastSelectedPlanId: 1,
    lastBackupAt: DateTime.utc(2026, 10, 1, 8),
  );
  final backup = BackupData(
    dataset: demo,
    settings: settings,
    schemaVersion: 1,
    appVersion: '1.0.0+12',
    exportedAt: testNow,
  );

  test('header fields (SPEC §8.2)', () {
    final json = jsonDecode(encodeBackup(backup)) as Map<String, Object?>;
    expect(json['format'], 'gymlog-backup');
    expect(json['formatVersion'], 9);
    expect(json['schemaVersion'], 1);
    expect(json['appVersion'], '1.0.0+12');
    expect(json['exportedAt'], isA<String>());
    expect((json['data']! as Map).keys, [
      'exercises',
      'plans',
      'planSchedules',
      'planExercises',
      'planGroups',
      'sessions',
      'sessionExercises',
      'sessionSupersets',
      'sets',
      'bodyWeights',
      'sessionHeartRates',
      'heartRateSamples',
      'settings',
    ]);
  });

  test('JSON round trip keeps every row and all columns', () {
    final decoded = decodeBackup(encodeBackup(backup));
    final d = decoded.dataset;
    expect(d.exercises, demo.exercises);
    expect(d.plans, demo.plans);
    expect(d.planExercises, demo.planExercises);
    expect(d.planGroups, demo.planGroups);
    expect(d.planGroups, isNotEmpty, reason: 'demo has groups');
    expect(d.sessions, demo.sessions);
    expect(d.sessionExercises, demo.sessionExercises);
    expect(d.sessionSupersets, demo.sessionSupersets);
    expect(d.sessionSupersets, isNotEmpty, reason: 'demo has supersets');
    expect(d.sets, demo.sets);
    expect(d.bodyWeights, demo.bodyWeights);
    expect(decoded.settings, settings);
    expect(decoded.exportedAt, testNow);
  });

  test('format 1 backups (before M9) are still read, without groups', () {
    final j = jsonDecode(encodeBackup(backup)) as Map<String, Object?>;
    j['formatVersion'] = 1;
    final data = j['data']! as Map<String, Object?>;
    data
      ..remove('planGroups')
      ..remove('sessionSupersets');
    for (final p in data['planExercises']! as List<Object?>) {
      (p! as Map<String, Object?>).remove('groupId');
    }
    for (final x in data['sessionExercises']! as List<Object?>) {
      (x! as Map<String, Object?>).remove('supersetId');
    }
    final d = decodeBackup(jsonEncode(j)).dataset;
    expect(d.planGroups, isEmpty);
    expect(d.sessionSupersets, isEmpty);
    expect(d.planExercises.every((p) => p.groupId == null), isTrue);
    expect(d.sessionExercises.every((x) => x.supersetId == null), isTrue);
    expect(d.sets, demo.sets);
  });

  test('format 2 backups (before 1.1.0) get the steps of the migration', () {
    final j = jsonDecode(encodeBackup(backup)) as Map<String, Object?>;
    j['formatVersion'] = 2;
    final data = j['data']! as Map<String, Object?>;
    final exercises = data['exercises']! as List<Object?>;
    for (final e in exercises) {
      (e! as Map<String, Object?>)
        ..remove('stepMode')
        ..remove('incrementLbs')
        ..remove('levelKg');
    }
    final present = {
      for (final e in exercises) (e! as Map<String, Object?>)['name'],
    };
    exercises.addAll([
      for (final (id, name) in [
        (900, 'Latzug'),
        (901, 'Bizepscurls am Kabel'),
        (902, 'Kurzhantel-Curls'),
      ])
        if (!present.contains(name))
          {
            'id': id,
            'name': name,
            'type': 'weight_reps',
            'category': null,
            'incrementKg': 2.5,
            'restSec': null,
            'includeInStrengthIndex': true,
            'notes': '',
            'archived': false,
            'createdAt': '2026-11-01T10:00:00.000Z',
          },
    ]);
    (data['settings']! as Map<String, Object?>)
      ..remove('defaultStep')
      ..remove('defaultStepUnit');
    final decoded = decodeBackup(jsonEncode(j));
    Exercise byName(String n) =>
        decoded.dataset.exercises.firstWhere((e) => e.name == n);
    expect(byName('Latzug').stepMode, StepMode.standard);
    expect(byName('Bizepscurls am Kabel').stepMode, StepMode.levels);
    expect(byName('Bizepscurls am Kabel').levelKg, 4.5);
    expect(byName('Kurzhantel-Curls').stepMode, StepMode.kg);
    expect(byName('Kurzhantel-Curls').incrementLbs, 15);
    expect(decoded.settings.defaultStep, 15);
    expect(decoded.settings.defaultStepUnit, WeightUnit.lbs);
  });

  test('format 3 backups (before 1.2.0): plans active, no training days, '
      'notification defaults', () {
    final j = jsonDecode(encodeBackup(backup)) as Map<String, Object?>;
    j['formatVersion'] = 3;
    final data = j['data']! as Map<String, Object?>;
    data.remove('planSchedules');
    for (final p in data['plans']! as List<Object?>) {
      (p! as Map<String, Object?>).remove('active');
    }
    final settings = data['settings']! as Map<String, Object?>;
    for (final key in [
      'notifyEvening',
      'eveningMinute',
      'notifyBefore',
      'beforeMinutes',
      'notifyRest',
      'notifyOpenSession',
      'notifyBackup',
      'notifyStreak',
      'checkUpdates',
      'bookingUrl',
    ]) {
      settings.remove(key);
    }
    final decoded = decodeBackup(jsonEncode(j));
    expect(decoded.dataset.plans.every((p) => p.active), isTrue);
    expect(decoded.dataset.planSchedules, isEmpty);
    expect(decoded.settings.notifyEvening, isTrue);
    expect(decoded.settings.bookingUrl, AppSettings.defaultBookingUrl);
  });

  test('countdown of the set timer: round trip; format 4 counts up '
      '(1.3.0)', () {
    final timedId = demo.exercises
        .firstWhere((e) => e.type == ExerciseType.timed)
        .id;
    final withCountdown = BackupData(
      dataset: Dataset(
        exercises: [
          for (final e in demo.exercises)
            e.copyWith(timerCountdown: e.id == timedId),
        ],
        plans: demo.plans,
        planExercises: demo.planExercises,
        planGroups: demo.planGroups,
        planSchedules: demo.planSchedules,
        sessions: demo.sessions,
        sessionExercises: demo.sessionExercises,
        sessionSupersets: demo.sessionSupersets,
        sets: demo.sets,
        bodyWeights: demo.bodyWeights,
      ),
      settings: settings,
      schemaVersion: 5,
      appVersion: '1.3.0+18',
      exportedAt: testNow,
    );
    final text = encodeBackup(withCountdown);
    final decoded = decodeBackup(text);
    expect(
      [
        for (final e in decoded.dataset.exercises)
          if (e.timerCountdown) e.id,
      ],
      [timedId],
    );

    final j = jsonDecode(text) as Map<String, Object?>;
    j['formatVersion'] = 4;
    for (final e
        in (j['data']! as Map<String, Object?>)['exercises']!
            as List<Object?>) {
      (e! as Map<String, Object?>).remove('timerCountdown');
    }
    expect(
      decodeBackup(jsonEncode(j)).dataset.exercises
          .any((e) => e.timerCountdown),
      isFalse,
    );
  });

  test('heart rate: summaries round trip, CSV, older formats, validation '
      '(1.5.0, 1.5.1)', () {
    final finished = demo.sessions.firstWhere((x) => !x.isActive);
    final kept = SessionHeartRate(
      sessionId: finished.id,
      avgBpm: 121,
      maxBpm: 158,
      minBpm: 88,
      seconds: 3000,
      histogram: '88:10,121:2900,158:90',
      curve: '95,,130',
    );
    final se = demo.sessionExercises.firstWhere(
      (x) => x.sessionId == finished.id,
    );
    final set = demo.sets.firstWhere((x) => x.sessionExerciseId == se.id);
    BackupData with7({
      List<SessionHeartRate> summaries = const [],
      List<HeartRateSample> buffer = const [],
    }) => BackupData(
      dataset: Dataset(
        exercises: demo.exercises,
        plans: demo.plans,
        planExercises: demo.planExercises,
        planGroups: demo.planGroups,
        planSchedules: demo.planSchedules,
        sessions: demo.sessions,
        sessionExercises: [
          for (final x in demo.sessionExercises)
            x.id == se.id ? x.copyWith(hrAvg: 120, hrMax: 150) : x,
        ],
        sessionSupersets: demo.sessionSupersets,
        sets: [
          for (final x in demo.sets)
            x.id == set.id
                ? SetEntry(
                    id: x.id,
                    sessionExerciseId: x.sessionExerciseId,
                    setIndex: x.setIndex,
                    weightKg: x.weightKg,
                    reps: x.reps,
                    durationSec: x.durationSec,
                    isWarmup: x.isWarmup,
                    completedAt: x.completedAt,
                    hrAvg: 131,
                    hrPeak: 149,
                  )
                : x,
        ],
        bodyWeights: demo.bodyWeights,
        heartRateSamples: buffer,
        sessionHeartRates: summaries,
      ),
      settings: settings,
      schemaVersion: 7,
      appVersion: '1.5.1+22',
      exportedAt: testNow,
    );
    final backup = with7(summaries: [kept]);
    final text = encodeBackup(backup);
    final decoded = decodeBackup(text).dataset;
    expect(decoded.sessionHeartRates, [kept]);
    expect(decoded.sets.firstWhere((x) => x.id == set.id).hrPeak, 149);
    expect(
      decoded.sessionExercises.firstWhere((x) => x.id == se.id).hrMax,
      150,
    );
    final csv = buildCsvExport(backup.dataset);
    expect(csv['sessions.csv'], contains(',121,158'));
    expect(csv['sets.csv'], contains(',131,149'));

    // Format 6 has no summaries.
    final j = jsonDecode(text) as Map<String, Object?>;
    j['formatVersion'] = 6;
    (j['data']! as Map<String, Object?>).remove('sessionHeartRates');
    expect(decodeBackup(jsonEncode(j)).dataset.sessionHeartRates, isEmpty);

    // Broken: twice the same training, a missing training, bad values.
    for (final broken in [
      with7(summaries: [kept, kept]),
      with7(
        summaries: [
          const SessionHeartRate(
            sessionId: 99999,
            avgBpm: 1,
            maxBpm: 1,
            minBpm: 1,
            seconds: 1,
            histogram: '',
            curve: '',
          ),
        ],
      ),
      with7(
        buffer: [
          HeartRateSample(
            id: 1,
            sessionId: finished.id,
            recordedAt: finished.startedAt,
            bpm: 400,
          ),
        ],
      ),
    ]) {
      expect(
        () => decodeBackup(encodeBackup(broken)),
        throwsA(isA<BackupFormatException>()),
      );
    }
  });

  test('1.6.0: profile, heart rate options, target time and recovery round '
      'trip; format 7 has none', () {
    final timed = demo.exercises.firstWhere(
      (e) => e.type == ExerciseType.timed,
    );
    final profile = settings.copyWith(
      hrMax: 185,
      birthYear: 1990,
      sex: Sex.female,
      hrWarnBpm: 176,
      hrPauseBpm: 105,
    );
    final finished = demo.sessions.firstWhere((x) => !x.isActive);
    final kept = SessionHeartRate(
      sessionId: finished.id,
      avgBpm: 120,
      maxBpm: 160,
      minBpm: 90,
      seconds: 600,
      histogram: '120:600',
      curve: '120',
      recoveryBpm: 28,
    );
    final data = BackupData(
      dataset: Dataset(
        exercises: [
          for (final e in demo.exercises)
            e.id == timed.id
                ? e.copyWith(
                    restByHeartRate: true,
                    hrTargetZone: 2,
                    hrTargetMinutes: 8,
                  )
                : e,
        ],
        plans: demo.plans,
        planExercises: demo.planExercises,
        planGroups: demo.planGroups,
        planSchedules: demo.planSchedules,
        sessions: demo.sessions,
        sessionExercises: demo.sessionExercises,
        sessionSupersets: demo.sessionSupersets,
        sets: demo.sets,
        bodyWeights: demo.bodyWeights,
        sessionHeartRates: [kept],
      ),
      settings: profile,
      schemaVersion: 8,
      appVersion: '1.6.0+23',
      exportedAt: testNow,
    );
    final text = encodeBackup(data);
    final decoded = decodeBackup(text);
    final e = decoded.dataset.exercises.firstWhere((x) => x.id == timed.id);
    expect(
      (e.restByHeartRate, e.hrTargetZone, e.hrTargetMinutes),
      (true, 2, 8),
    );
    expect(decoded.dataset.sessionHeartRates.single.recoveryBpm, 28);
    final s = decoded.settings;
    expect(
      (s.hrMax, s.birthYear, s.sex, s.hrWarnBpm, s.hrPauseBpm),
      (185, 1990, Sex.female, 176, 105),
    );

    final j = jsonDecode(text) as Map<String, Object?>;
    j['formatVersion'] = 7;
    final old = decodeBackup(jsonEncode(j));
    expect(old.settings.hrMax, isNull);
    expect(old.settings.hrThreshold, isNull);
    expect(old.dataset.exercises.any((x) => x.restByHeartRate), isFalse);
    expect(old.dataset.sessionHeartRates.single.recoveryBpm, isNull);
  });

  test('1.6.1: lactate threshold heart rate; format 8 has none', () {
    final data = BackupData(
      dataset: demo,
      settings: settings.copyWith(hrThreshold: 170, hrWarnBpm: 182),
      schemaVersion: 9,
      appVersion: '1.6.1+24',
      exportedAt: testNow,
    );
    final text = encodeBackup(data);
    expect(
      (
        decodeBackup(text).settings.hrThreshold,
        decodeBackup(text).settings.hrWarnBpm,
      ),
      (170, 182),
    );
    final j = jsonDecode(text) as Map<String, Object?>;
    j['formatVersion'] = 8;
    final old = decodeBackup(jsonEncode(j));
    expect(old.settings.hrThreshold, isNull);
    expect(old.settings.hrWarnBpm, 182, reason: 'known since format 8');
  });

  test('training days: round trip and validation (1.2.0)', () {
    final planId = demo.plans.first.id;
    final withDays = BackupData(
      dataset: Dataset(
        exercises: demo.exercises,
        plans: [for (final p in demo.plans) p.copyWith(active: p.id == planId)],
        planExercises: demo.planExercises,
        planGroups: demo.planGroups,
        planSchedules: [
          PlanScheduleEntry(
            id: 1,
            planId: planId,
            weekday: 1,
            minuteOfDay: 1080,
          ),
          PlanScheduleEntry(
            id: 2,
            planId: planId,
            weekday: 4,
            minuteOfDay: 1110,
          ),
        ],
        sessions: demo.sessions,
        sessionExercises: demo.sessionExercises,
        sessionSupersets: demo.sessionSupersets,
        sets: demo.sets,
        bodyWeights: demo.bodyWeights,
      ),
      settings: settings.copyWith(eveningMinute: 19 * 60, notifyStreak: false),
      schemaVersion: 4,
      appVersion: '1.2.0+15',
      exportedAt: testNow,
    );
    final decoded = decodeBackup(encodeBackup(withDays));
    expect(decoded.dataset.planSchedules, withDays.dataset.planSchedules);
    expect(decoded.dataset.plans, withDays.dataset.plans);
    expect(decoded.settings.eveningMinute, 19 * 60);
    expect(decoded.settings.notifyStreak, isFalse);

    final j = jsonDecode(encodeBackup(withDays)) as Map<String, Object?>;
    final days =
        (j['data']! as Map<String, Object?>)['planSchedules']! as List<Object?>;
    (days.last! as Map<String, Object?>)['weekday'] = 1;
    expect(
      () => decodeBackup(jsonEncode(j)),
      throwsA(isA<BackupFormatException>()),
      reason: 'two times Monday',
    );
  });

  test('preview: trainings, period, body weights', () {
    final p = previewOf(demo);
    expect(p.trainings, demo.sessions.length);
    expect(p.first, demo.sessions.first.startedAt);
    expect(p.last, demo.sessions.last.startedAt);
    expect(p.bodyWeights, demo.bodyWeights.length);
  });

  group('validation (SPEC §8.3)', () {
    Map<String, Object?> json() =>
        jsonDecode(encodeBackup(backup)) as Map<String, Object?>;
    Map<String, Object?> data(Map<String, Object?> j) =>
        j['data']! as Map<String, Object?>;
    List<Object?> list(Map<String, Object?> j, String key) =>
        data(j)[key]! as List<Object?>;
    Map<String, Object?> first(Map<String, Object?> j, String key) =>
        list(j, key).first! as Map<String, Object?>;

    final cases = <(String, String Function(), BackupError)>[
      ('not JSON', () => 'kein json', BackupError.notJson),
      ('JSON array', () => '[]', BackupError.notJson),
      (
        'wrong format',
        () {
          final j = json()..['format'] = 'other';
          return jsonEncode(j);
        },
        BackupError.wrongFormat,
      ),
      (
        'newer version',
        () {
          final j = json()..['formatVersion'] = 10;
          return jsonEncode(j);
        },
        BackupError.newerVersion,
      ),
      (
        'missing field',
        () {
          final j = json();
          first(j, 'sets').remove('setIndex');
          return jsonEncode(j);
        },
        BackupError.invalidField,
      ),
      (
        'wrong type',
        () {
          final j = json();
          first(j, 'exercises')['incrementKg'] = '2,5';
          return jsonEncode(j);
        },
        BackupError.invalidField,
      ),
      (
        'unknown enum code',
        () {
          final j = json();
          first(j, 'exercises')['type'] = 'cardio';
          return jsonEncode(j);
        },
        BackupError.invalidField,
      ),
      (
        'invalid date',
        () {
          final j = json();
          first(j, 'bodyWeights')['date'] = '2026-02-30';
          return jsonEncode(j);
        },
        BackupError.invalidField,
      ),
      (
        'broken reference',
        () {
          final j = json();
          first(j, 'sets')['sessionExerciseId'] = 99999;
          return jsonEncode(j);
        },
        BackupError.brokenReference,
      ),
      (
        'plan exercise in a missing group',
        () {
          final j = json();
          first(j, 'planExercises')['groupId'] = 99999;
          return jsonEncode(j);
        },
        BackupError.brokenReference,
      ),
      (
        'plan exercise in a group of another plan',
        () {
          final j = json();
          final group = first(j, 'planGroups');
          final other = list(j, 'planExercises')
              .cast<Map<String, Object?>>()
              .firstWhere((p) => p['planId'] != group['planId']);
          other['groupId'] = group['id'];
          return jsonEncode(j);
        },
        BackupError.brokenReference,
      ),
      (
        'session exercise in a missing superset',
        () {
          final j = json();
          first(j, 'sessionExercises')['supersetId'] = 99999;
          return jsonEncode(j);
        },
        BackupError.brokenReference,
      ),
      (
        'missing group list in format 2',
        () {
          final j = json();
          data(j).remove('planGroups');
          return jsonEncode(j);
        },
        BackupError.invalidField,
      ),
      (
        'unknown group kind',
        () {
          final j = json();
          first(j, 'planGroups')['kind'] = 'circuit';
          return jsonEncode(j);
        },
        BackupError.invalidField,
      ),
      (
        'settings point to a missing plan',
        () {
          final j = json();
          (data(j)['settings']! as Map<String, Object?>)['lastSelectedPlanId'] =
              999;
          return jsonEncode(j);
        },
        BackupError.brokenReference,
      ),
      (
        'duplicate id',
        () {
          final j = json();
          list(j, 'plans').add(list(j, 'plans').first);
          return jsonEncode(j);
        },
        BackupError.duplicate,
      ),
      (
        'names differing only in case',
        () {
          final j = json();
          final copy = Map<String, Object?>.from(first(j, 'exercises'))
            ..['id'] = 999
            ..['name'] = 'BANKDRÜCKEN';
          list(j, 'exercises').add(copy);
          return jsonEncode(j);
        },
        BackupError.duplicate,
      ),
      (
        'two running sessions',
        () {
          final j = json();
          for (final s in list(j, 'sessions').take(2)) {
            (s! as Map<String, Object?>)['endedAt'] = null;
          }
          return jsonEncode(j);
        },
        BackupError.severalActiveSessions,
      ),
    ];
    for (final (name, build, error) in cases) {
      test(name, () {
        expect(
          () => decodeBackup(build()),
          throwsA(
            isA<BackupFormatException>().having((e) => e.error, 'error', error),
          ),
        );
      });
    }
  });

  group('CSV export (SPEC §8.1)', () {
    final files = buildCsvExport(demo);
    List<String> lines(String name) => files[name]!.split('\r\n')..removeLast();

    test('four files with the exact headers', () {
      expect(files.keys.toSet(), {
        'sets.csv',
        'sessions.csv',
        'body_weight.csv',
        'exercises.csv',
      });
      expect(
        lines('sets.csv').first,
        'session_id,session_date,session_started_at,plan_name,exercise_id,'
        'exercise_name,exercise_type,category,exercise_position,set_index,'
        'weight_kg,reps,duration_s,is_warmup,e1rm_kg,completed_at,weight_unit,'
        'hr_avg_bpm,hr_peak_bpm',
      );
      expect(
        lines('sessions.csv').first,
        'session_id,plan_name,started_at,ended_at,duration_s,n_exercises,'
        'n_sets,volume_kg,notes,hr_avg_bpm,hr_max_bpm',
      );
      expect(lines('body_weight.csv').first, 'date,weight_kg');
      expect(
        lines('exercises.csv').first,
        'exercise_id,name,type,category,increment_kg,'
        'include_in_strength_index,archived,notes,step_mode,increment_lbs,'
        'level_kg',
      );
    });

    test('one row per set / session / entry / exercise', () {
      expect(lines('sets.csv'), hasLength(demo.sets.length + 1));
      expect(lines('sessions.csv'), hasLength(demo.sessions.length + 1));
      expect(lines('body_weight.csv'), hasLength(demo.bodyWeights.length + 1));
      expect(lines('exercises.csv'), hasLength(demo.exercises.length + 1));
    });

    test('values: codes, point decimals, e1RM only for weight_reps', () {
      final row = lines('sets.csv')[1].split(',');
      expect(row[6], anyOf('weight_reps', 'bodyweight', 'timed'));
      final bench = lines('sets.csv')
          .firstWhere((l) => l.contains('Bankdrücken'));
      final cols = bench.split(',');
      expect(double.parse(cols[10]), greaterThan(0));
      expect(cols[14], isNotEmpty);
      final plank = lines('sets.csv').firstWhere((l) => l.contains(',Plank,'));
      expect(plank.split(',')[14], isEmpty);
      expect(plank.split(',')[11], isEmpty, reason: 'reps null → empty');
    });

    test('only finished sessions', () {
      final withActive = Dataset(
        exercises: demo.exercises,
        plans: demo.plans,
        sessions: [
          ...demo.sessions,
          Session(
            id: 9999,
            planId: null,
            planNameSnapshot: null,
            startedAt: testNow,
            endedAt: null,
            notes: '',
          ),
        ],
        sessionExercises: demo.sessionExercises,
        sets: demo.sets,
        bodyWeights: demo.bodyWeights,
      );
      expect(
        buildCsvExport(withActive)['sessions.csv']!.split('\r\n').length,
        files['sessions.csv']!.split('\r\n').length,
      );
    });
  });
}
