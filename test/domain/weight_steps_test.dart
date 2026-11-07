import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/weight_steps.dart';

void main() {
  group('KgStep', () {
    test('adds and subtracts the step, without float noise', () {
      const s = KgStep(2.5);
      expect(s.up(60), 62.5);
      expect(s.down(60), 57.5);
      expect(const KgStep(0.1).up(0.2), 0.3);
    });
  });

  group('LbsStep: lbs plates with kg rounded (1.1.0)', () {
    const s = LbsStep(15);

    test('printed kg values of the plates 85 … 220 lbs', () {
      expect(
        [for (var lbs = 85.0; lbs <= 220; lbs += 15) kgOfLbs(lbs)],
        [39, 45, 52, 59, 66, 73, 79, 86, 93, 100],
      );
    });

    test('the user\'s plates 45, 59, 66, 100 kg follow each other', () {
      var w = 45.0;
      final up = <double>[];
      for (var i = 0; i < 6; i++) {
        w = s.up(w);
        up.add(w);
      }
      expect(up, [52, 59, 66, 73, 79, 86]);
      expect(s.up(93), 100);
      expect(s.down(100), 93);
      expect(s.down(45), 39);
    });

    test('a weight between plates moves to the next real plate', () {
      expect(s.up(40), 48, reason: '40 kg ≈ 90 lbs → 105 lbs');
      expect(s.up(38), 45, reason: '38 kg ≈ 85 lbs → 100 lbs');
      expect(s.down(41), 34);
      for (final w in [0.0, 3.0, 17.5, 38.0, 61.3, 99.0]) {
        expect(s.up(w), greaterThan(w), reason: '$w');
        expect(s.down(w), lessThanOrEqualTo(w), reason: '$w');
      }
    });

    test('from 0 and down to 0', () {
      expect(s.up(0), 7, reason: '15 lbs = 6.8 kg');
      expect(s.down(7), 0);
      expect(s.down(0), 0);
    });

    test('negative weights (assistance) mirror the steps', () {
      expect(s.down(-45), -52);
      expect(s.up(-52), -45);
    });

    test('other steps, e.g. 10 lbs', () {
      expect(const LbsStep(10).up(45), 50, reason: '100 → 110 lbs = 49.9');
    });
  });

  group('LevelStep', () {
    test('with kg per level: stores kg, moves by whole levels', () {
      const s = LevelStep(4.5);
      expect(s.weightOf(10), 45);
      expect(s.levelOf(45), 10);
      expect(s.up(45), 49.5);
      expect(s.down(45), 40.5);
      expect(s.up(0), 4.5);
      expect(s.down(4.5), 0);
      expect(s.down(0), 0);
    });

    test('an old kg value between levels moves to the next whole level', () {
      const s = LevelStep(4.5);
      expect(s.levelOf(40), closeTo(8.89, 0.01));
      expect(s.up(40), 40.5, reason: 'level 9');
      expect(s.down(40), 36, reason: 'level 8');
    });

    test('without kg: the level number is the stored weight', () {
      const s = LevelStep(null);
      expect(s.up(9), 10);
      expect(s.down(10), 9);
      expect(s.weightOf(7), 7);
    });
  });

  group('weightStepOf', () {
    Exercise ex(StepMode mode, {double? levelKg}) => Exercise(
      id: 1,
      name: 'X',
      type: ExerciseType.weightReps,
      category: null,
      incrementKg: 2,
      restSec: null,
      includeInStrengthIndex: true,
      notes: '',
      archived: false,
      createdAt: DateTime.utc(2026),
      stepMode: mode,
      incrementLbs: 10,
      levelKg: levelKg,
    );

    test('standard follows the settings, others their own values', () {
      const lbs = AppSettings.defaults;
      final kg = lbs.copyWith(defaultStep: 5, defaultStepUnit: WeightUnit.kg);
      expect(weightStepOf(ex(StepMode.standard), lbs), const LbsStep(15));
      expect(weightStepOf(ex(StepMode.standard), kg), const KgStep(5));
      expect(weightStepOf(ex(StepMode.kg), lbs), const KgStep(2));
      expect(weightStepOf(ex(StepMode.lbs), lbs), const LbsStep(10));
      expect(
        weightStepOf(ex(StepMode.levels, levelKg: 4.5), lbs),
        const LevelStep(4.5),
      );
    });

    test('levels and kg storage', () {
      expect(levelsOf(ex(StepMode.kg)), isNull);
      expect(levelsOf(ex(StepMode.levels)), const LevelStep(null));
      expect(storesKg(ex(StepMode.levels)), isFalse);
      expect(storesKg(ex(StepMode.levels, levelKg: 4.5)), isTrue);
      expect(storesKg(ex(StepMode.standard)), isTrue);
    });
  });
}
