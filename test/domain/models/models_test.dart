import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/models.dart';

void main() {
  final exercise = Exercise(
    id: 1,
    name: 'Rudern',
    type: ExerciseType.weightReps,
    category: ExerciseCategory.back,
    incrementKg: 2.5,
    restSec: 120,
    includeInStrengthIndex: true,
    notes: '',
    archived: false,
    createdAt: DateTime.utc(2026),
  );

  test('copyWith keeps nullable fields unless passed, null clears them', () {
    expect(exercise.copyWith(name: 'X').restSec, 120);
    expect(exercise.copyWith(restSec: null).restSec, isNull);
    expect(exercise.copyWith(category: null).category, isNull);
    expect(exercise.copyWith(), exercise);
  });

  test('AppSettings defaults follow SPEC §5', () {
    const s = AppSettings.defaults;
    expect(s.id, 1);
    expect(s.defaultSets, 3);
    expect(s.defaultRestSec, 90);
    expect(s.restTimerEnabled, isTrue);
    expect(s.vibrationEnabled, isTrue);
    expect(s.keepScreenOn, isTrue);
    expect(s.autoActivateNext, isFalse);
    expect(s.themeMode, ThemePreference.system);
    expect(s.lastSelectedPlanId, isNull);
    expect(s.lastBackupAt, isNull);
    expect(s.backupReminderDays, 14);
    expect(s.copyWith(lastSelectedPlanId: 4).copyWith().lastSelectedPlanId, 4);
    expect(
      s.copyWith(lastSelectedPlanId: 4).copyWith(lastSelectedPlanId: null),
      s,
    );
  });

  test('ExerciseDraft derives includeInStrengthIndex from the type', () {
    expect(
      const ExerciseDraft(
        name: 'a',
        type: ExerciseType.timed,
      ).includeInStrengthIndex,
      isFalse,
    );
    expect(
      const ExerciseDraft(
        name: 'a',
        type: ExerciseType.bodyweight,
      ).includeInStrengthIndex,
      isTrue,
    );
    expect(
      const ExerciseDraft(
        name: 'a',
        type: ExerciseType.timed,
        includeInStrengthIndex: true,
      ).includeInStrengthIndex,
      isTrue,
    );
  });

  test('Session state helpers', () {
    final s = Session(
      id: 1,
      planId: null,
      planNameSnapshot: null,
      startedAt: DateTime.utc(2026),
      endedAt: null,
      notes: '',
    );
    expect(s.isActive, isTrue);
    expect(s.isFreeTraining, isTrue);
    expect(s.copyWith(endedAt: DateTime.utc(2026, 1, 2)).isActive, isFalse);
  });
}
