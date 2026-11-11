import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/fitnotes_import.dart';
import 'package:gymlog/domain/models/models.dart';

/// 1.4.0: FitNotes workout export (sample of the user in
/// test/fixtures/fitnotes_workout.txt, a copy of docs/export.txt).
void main() {
  final sample = File('test/fixtures/fitnotes_workout.txt').readAsStringSync();

  Exercise ex(
    int id,
    String name,
    ExerciseType type, {
    StepMode stepMode = StepMode.kg,
    double? levelKg,
    bool archived = false,
  }) => Exercise(
    id: id,
    name: name,
    type: type,
    category: null,
    incrementKg: 2.5,
    restSec: null,
    includeInStrengthIndex: true,
    notes: '',
    archived: archived,
    createdAt: DateTime.utc(2026),
    stepMode: stepMode,
    levelKg: levelKg,
  );

  group('the sample of the user', () {
    final w = parseFitNotes(sample);
    FitNotesExercise byName(String n) =>
        w.exercises.firstWhere((e) => e.name == n);

    test('date, day, all 15 exercises in order, 0-rep sets left out', () {
      expect(w.date, LocalDate(2026, 11, 2));
      expect(w.dayLabel, 'Montag');
      expect(w.exercises, hasLength(15));
      expect(w.exercises.first.name, 'Flat Barbell Bench Press');
      expect(w.exercises.last.name, 'Isometric Neutral Pull Up');
      expect(w.skippedSets, 2);
      expect(w.unreadLines, isEmpty);
      expect(w.setCount, 47);
    });

    test('types and targets', () {
      final bench = byName('Flat Barbell Bench Press');
      expect(bench.type, ExerciseType.weightReps);
      expect((bench.targetSets, bench.targetReps), (3, 12));
      expect(bench.typicalWeightKg, 52.5);
      expect(bench.sets.last, (weightKg: 52.5, reps: 9, durationSec: null));

      final ring = byName('Ring Push Up');
      expect(ring.type, ExerciseType.bodyweight);
      expect((ring.targetSets, ring.targetReps), (3, 12));

      final hold = byName('Isometric Neutral Pull Up');
      expect(hold.type, ExerciseType.timed);
      expect(
        (hold.targetSets, hold.targetDurationSec, hold.targetReps),
        (3, 30, null),
      );
      expect(hold.sets.last.durationSec, 25);

      final row = byName('One Arm Row Lat Machine');
      expect((row.targetSets, row.targetReps), (5, 12));
      // Whitespace of names is cleaned, brackets inside the name stay.
      expect(
        w.exercises.map((e) => e.name),
        containsAll([
          'Triceps KZ SZ Push Down Untergriff',
          'Back Extensions (Rolling)',
        ]),
      );
    });

    test('groups: "Rotate" → rotation, "Set" → superset, none → none', () {
      expect(
        byName('Flat Barbell Bench Press').group,
        'Weekly Rotate Chest Monday',
      );
      expect(
        byName('Flat Barbell Bench Press').groupKind,
        PlanGroupKind.rotation,
      );
      expect(byName('Cable Crunch').groupKind, PlanGroupKind.superset);
      expect(byName('Ring Push Up').group, isNull);
      expect(byName('Ring Push Up').groupKind, isNull);
    });
  });

  group('parser details', () {
    test('lbs, weight × time, h:mm:ss, a name twice, unknown lines', () {
      final w = parseFitNotes('''
FitNotes Workout - Monday, 3 March 2025

** Squat **
- 135 lbs x 5 reps
- 100.5 kgs x 5 reps

** Farmer Walk **
- 20.0 kgs x 01:00
- 1:02:03

** Rowing **
- 5.0 km

** squat **
- 140 lbs x 0 reps
- 60,0 kg x 3 reps
''');
      expect(w.date, LocalDate(2025, 3, 3));
      expect(w.dayLabel, 'Monday');
      final squat = w.exercises.first;
      expect(squat.sets.map((s) => s.weightKg), [61.23, 100.5, 60.0]);
      expect(w.skippedSets, 1);
      final walk = w.exercises[1];
      expect(walk.type, ExerciseType.timed);
      expect(walk.sets.map((s) => (s.weightKg, s.durationSec)), [
        (20.0, 60),
        (null, 3723),
      ]);
      // Without readable sets an exercise is left out; its line is listed.
      expect(w.exercises.map((e) => e.name), ['Squat', 'Farmer Walk']);
      expect(w.unreadLines, ['- 5.0 km']);
    });

    test('not an export, several workouts, nothing to import', () {
      expect(
        () => parseFitNotes('Hallo'),
        throwsA(isA<FitNotesFormatException>()),
      );
      expect(
        () => parseFitNotes(
          'FitNotes Workout - Mo 1st June 2026\n** A **\n- 5 reps\n'
          'FitNotes Workout - Di 2nd June 2026\n** B **\n- 5 reps\n',
        ),
        throwsA(isA<FitNotesFormatException>()),
      );
      expect(
        () => parseFitNotes('FitNotes Workout - x\n** A **\n- 0 reps\n'),
        throwsA(isA<FitNotesFormatException>()),
      );
      // An unreadable date is no reason to fail.
      final w = parseFitNotes(
        'FitNotes Workout - irgendwann\n** A **\n- 5 reps',
      );
      expect((w.date, w.dayLabel), (null, 'irgendwann'));
    });

    test('mixed lines: the sets that fit the type', () {
      final w = parseFitNotes(
        'FitNotes Workout - 1st June 2026\n** A **\n- 10.0 kgs x 8 reps\n- 8 reps\n',
      );
      expect(w.exercises.single.type, ExerciseType.weightReps);
      expect(w.exercises.single.sets, hasLength(1));
    });
  });

  group('matching GymLog exercises', () {
    final w = parseFitNotes(sample);
    FitNotesExercise byName(String n) =>
        w.exercises.firstWhere((e) => e.name == n);
    final library = [
      ex(1, 'Bankdrücken', ExerciseType.weightReps),
      ex(2, 'Hip Thrust', ExerciseType.weightReps),
      ex(3, 'Crunches am Kabel', ExerciseType.weightReps),
      ex(4, 'Liegestütze', ExerciseType.bodyweight),
      ex(5, 'Klimmzüge', ExerciseType.bodyweight),
      ex(6, 'Plank', ExerciseType.timed),
      ex(7, 'Ring Push Up', ExerciseType.weightReps),
    ];

    test('same name or alias, only if the sets fit', () {
      expect(
        suggestExercise(byName('Flat Barbell Bench Press'), library)?.id,
        1,
      );
      expect(suggestExercise(byName('Hip Thrust'), library)?.id, 2);
      expect(suggestExercise(byName('Cable Crunch'), library)?.id, 3);
      // Same name, but reps only cannot go into a weight × reps exercise.
      expect(suggestExercise(byName('Ring Push Up'), library), isNull);
      expect(
        suggestExercise(byName('Seated Cable Face Pull'), library),
        isNull,
      );
    });

    test('compatibility', () {
      final bench = byName('Flat Barbell Bench Press');
      final ring = byName('Ring Push Up');
      final hold = byName('Isometric Neutral Pull Up');
      expect(canImportInto(bench, library[0]), isTrue);
      // Weight × reps as added weight of a bodyweight exercise.
      expect(canImportInto(bench, library[4]), isTrue);
      expect(canImportInto(ring, library[3]), isTrue);
      expect(canImportInto(ring, library[0]), isFalse);
      expect(canImportInto(hold, library[5]), isTrue);
      expect(canImportInto(hold, library[4]), isFalse);
      // Levels without kg store level numbers, not kg.
      expect(
        canImportInto(
          bench,
          ex(8, 'X', ExerciseType.weightReps, stepMode: StepMode.levels),
        ),
        isFalse,
      );
      expect(
        canImportInto(
          bench,
          ex(
            9,
            'Y',
            ExerciseType.weightReps,
            stepMode: StepMode.levels,
            levelKg: 5,
          ),
        ),
        isTrue,
      );
      expect(
        canImportInto(
          bench,
          ex(10, 'Z', ExerciseType.weightReps, archived: true),
        ),
        isFalse,
      );
    });

    test('categories of new exercises', () {
      expect(guessCategory('Flat Barbell Bench Press'), ExerciseCategory.chest);
      expect(guessCategory('Cable Flys One Arm'), ExerciseCategory.chest);
      expect(guessCategory("Back Fly's KZ"), ExerciseCategory.shoulders);
      expect(guessCategory('One Arm Row Lat Machine'), ExerciseCategory.back);
      expect(guessCategory('Reverse Crunches'), ExerciseCategory.core);
      expect(
        guessCategory('OH Inclined Cable Triceps Pull SZ'),
        ExerciseCategory.arms,
      );
      expect(
        guessCategory('Seated Cable Face Pull'),
        ExerciseCategory.shoulders,
      );
      expect(guessCategory('Hip Thrust'), ExerciseCategory.legs);
      expect(guessCategory('Isometric Neutral Pull Up'), ExerciseCategory.back);
      expect(guessCategory('Back Extensions (Rolling)'), ExerciseCategory.back);
      expect(guessCategory('Juggling'), isNull);
    });
  });
}
