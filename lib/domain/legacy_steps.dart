/// Weight steps of exercises from before 1.1.0, used by the database
/// migration 2 → 3 and when restoring an older backup. Never edit an entry
/// once released: both must do the same on every phone, whatever the library
/// looks like later.
library;

import 'models/models.dart';
import 'names.dart';

/// Schema 2 → 3 (1.1.0): built-in exercises on machines and cables switch to
/// the default step of the settings (15 lbs plates in the user's gym).
/// Plate-loaded machines (Hackenschmidt) and free weights keep kg steps.
const v3StandardStepExercises = [
  'Brustpresse (Maschine)',
  'Schräge Brustpresse (Maschine)',
  'Butterfly (Maschine)',
  'Cable Crossover',
  'Latzug',
  'Latzug eng',
  'Rudern am Kabel (sitzend)',
  'Rudern (Maschine)',
  'Pullover am Kabel',
  'Rückenstrecker (Maschine)',
  'Beinpresse',
  'Beinstrecker (Maschine)',
  'Beinbeuger liegend (Maschine)',
  'Beinbeuger sitzend (Maschine)',
  'Glute-Kickbacks am Kabel',
  'Abduktoren (Maschine)',
  'Adduktoren (Maschine)',
  'Wadenheben stehend (Maschine)',
  'Wadenheben sitzend (Maschine)',
  'Schulterpresse (Maschine)',
  'Seitheben am Kabel',
  'Seitheben (Maschine)',
  'Reverse Butterfly (Maschine)',
  'Face Pulls',
  'Scott-Curls (Maschine)',
  'Trizeps-Dips (Maschine)',
  'Crunches (Maschine)',
  'Crunches am Kabel',
  'Pallof Press',
];

/// Schema 2 → 3: the cable tower with numbered plates 1–15, 4.5 kg each.
const v3LevelExercises = [
  'Bizepscurls am Kabel',
  'Trizepsdrücken am Kabel',
  'Trizepsdrücken über Kopf (Kabel)',
];
const v3LevelKg = 4.5;

/// The step mode an exercise from before 1.1.0 gets.
StepMode legacyStepMode(String name, ExerciseType type) {
  if (type != ExerciseType.weightReps) return StepMode.kg;
  final key = nameKey(name);
  if (v3LevelExercises.any((n) => nameKey(n) == key)) return StepMode.levels;
  if (v3StandardStepExercises.any((n) => nameKey(n) == key)) {
    return StepMode.standard;
  }
  return StepMode.kg;
}
