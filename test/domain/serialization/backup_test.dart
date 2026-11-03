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
    expect(json['formatVersion'], 1);
    expect(json['schemaVersion'], 1);
    expect(json['appVersion'], '1.0.0+12');
    expect(json['exportedAt'], isA<String>());
    expect((json['data']! as Map).keys, [
      'exercises',
      'plans',
      'planExercises',
      'sessions',
      'sessionExercises',
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
    expect(d.sessions, demo.sessions);
    expect(d.sessionExercises, demo.sessionExercises);
    expect(d.sets, demo.sets);
    expect(d.bodyWeights, demo.bodyWeights);
    expect(decoded.settings, settings);
    expect(decoded.exportedAt, testNow);
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
          final j = json()..['formatVersion'] = 2;
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
        'weight_kg,reps,duration_s,is_warmup,e1rm_kg,completed_at',
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
        'include_in_strength_index,archived,notes',
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
