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
    expect(json['formatVersion'], 4);
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
          final j = json()..['formatVersion'] = 5;
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
        'weight_kg,reps,duration_s,is_warmup,e1rm_kg,completed_at,weight_unit',
      );
      expect(
        lines('sessions.csv').first,
        'session_id,plan_name,started_at,ended_at,duration_s,n_exercises,'
        'n_sets,volume_kg,notes',
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
