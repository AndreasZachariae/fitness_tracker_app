import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/exercise_library.dart';
import 'package:gymlog/domain/legacy_steps.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/names.dart';

void main() {
  group('exercise library', () {
    test('has a broad set of exercises', () {
      expect(exerciseLibrary.length, greaterThanOrEqualTo(80));
    });

    test('names are valid, already clean and unique (ignoring case)', () {
      final keys = <String>{};
      for (final e in exerciseLibrary) {
        expect(isValidName(e.name), isTrue, reason: e.name);
        expect(cleanName(e.name), e.name, reason: e.name);
        expect(keys.add(nameKey(e.name)), isTrue, reason: 'twice: ${e.name}');
      }
    });

    test('every category is used and every exercise has one', () {
      expect(
        exerciseLibrary.map((e) => e.category).toSet(),
        ExerciseCategory.values.toSet(),
      );
    });

    test('contains all three exercise types', () {
      final byType = {
        for (final t in ExerciseType.values)
          t: exerciseLibrary.where((e) => e.type == t).length,
      };
      expect(byType[ExerciseType.weightReps], greaterThan(50));
      expect(byType[ExerciseType.bodyweight], greaterThanOrEqualTo(10));
      expect(byType[ExerciseType.timed], greaterThanOrEqualTo(8));
    });

    test('strength index follows the default rule of the type', () {
      for (final e in exerciseLibrary) {
        expect(
          e.includeInStrengthIndex,
          e.type != ExerciseType.timed,
          reason: e.name,
        );
      }
    });

    test('weight steps are plausible and valid for the repository', () {
      for (final e in exerciseLibrary) {
        expect(e.incrementKg, inInclusiveRange(1, 5), reason: e.name);
        expect(e.restSec, isNull, reason: e.name);
        expect(e.notes, isEmpty, reason: e.name);
      }
      final weight = {for (final e in exerciseLibrary) e.name: e.incrementKg};
      expect(weight['Bankdrücken'], 2.5);
      expect(weight['Kurzhantel-Curls'], 2.0);
      expect(weight['Beinpresse'], 5.0);
    });

    test('classic examples sit in the right category', () {
      final category = {
        for (final e in exerciseLibrary) e.name: (e.category, e.type),
      };
      expect(category['Bankdrücken'], (
        ExerciseCategory.chest,
        ExerciseType.weightReps,
      ));
      expect(category['Klimmzüge'], (
        ExerciseCategory.back,
        ExerciseType.bodyweight,
      ));
      expect(category['Beinpresse']?.$1, ExerciseCategory.legs);
      expect(
        category['Seitheben (Kurzhantel)']?.$1,
        ExerciseCategory.shoulders,
      );
      expect(category['SZ-Curls']?.$1, ExerciseCategory.arms);
      expect(category['Plank'], (ExerciseCategory.core, ExerciseType.timed));
      expect(category['Laufband'], (
        ExerciseCategory.other,
        ExerciseType.timed,
      ));
    });
  });

  group('weight steps (1.1.0)', () {
    Set<String> withMode(StepMode m) => {
      for (final e in exerciseLibrary)
        if (e.stepMode == m) e.name,
    };

    test('machines and cables use the default step, as in the migration', () {
      expect(withMode(StepMode.standard), v3StandardStepExercises.toSet());
      expect(withMode(StepMode.levels), v3LevelExercises.toSet());
      expect(withMode(StepMode.lbs), isEmpty);
    });

    test('cable curls: levels with 4.5 kg; free weights keep kg steps', () {
      final byName = {for (final e in exerciseLibrary) e.name: e};
      expect(byName['Bizepscurls am Kabel']!.levelKg, 4.5);
      expect(byName['Bankdrücken']!.stepMode, StepMode.kg);
      expect(byName['Kurzhantel-Curls']!.stepMode, StepMode.kg);
      expect(byName['Hackenschmidt-Kniebeugen']!.stepMode, StepMode.kg);
      expect(byName['Klimmzüge']!.stepMode, StepMode.kg);
    });

    test('legacyStepMode matches names like the migration', () {
      expect(
        legacyStepMode('latzug', ExerciseType.weightReps),
        StepMode.standard,
      );
      expect(legacyStepMode('Latzug', ExerciseType.bodyweight), StepMode.kg);
      expect(
        legacyStepMode('Trizepsdrücken am Kabel', ExerciseType.weightReps),
        StepMode.levels,
      );
      expect(legacyStepMode('Eigene', ExerciseType.weightReps), StepMode.kg);
    });
  });

  group('missingLibraryExercises', () {
    test('everything is missing in an empty library', () {
      expect(missingLibraryExercises(const []), exerciseLibrary);
    });

    test('skips taken names, ignoring case and extra spaces', () {
      final missing = missingLibraryExercises([
        'bankdrücken',
        '  PLANK ',
        'Mein Spezialcurl',
      ]);
      expect(missing.length, exerciseLibrary.length - 2);
      expect(missing.map((e) => e.name), isNot(contains('Bankdrücken')));
      expect(missing.map((e) => e.name), isNot(contains('Plank')));
    });

    test('nothing is missing once all names exist', () {
      expect(
        missingLibraryExercises(exerciseLibrary.map((e) => e.name)),
        isEmpty,
      );
    });
  });
}
