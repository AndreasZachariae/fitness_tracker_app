/// The built-in exercise library (v1.0.0): classic gym exercises on
/// machines, cables and free weights, plus bodyweight and timed exercises.
///
/// A fresh database starts with it; Settings → Übungen can add missing ones
/// later. Names are data, not UI texts, but they are German like the UI.
library;

import 'models/models.dart';
import 'names.dart';

/// Weight steps: barbell plates, dumbbell racks, machine stacks.
const _barbell = 2.5;
const _dumbbell = 2.0;
const _machine = 5.0;
const _cable = 2.5;
const _kettlebell = 4.0;

const _w = ExerciseType.weightReps;
const _bw = ExerciseType.bodyweight;
const _t = ExerciseType.timed;

ExerciseDraft _ex(
  String name,
  ExerciseType type,
  ExerciseCategory category, [
  double incrementKg = ExerciseDraft.defaultIncrementKg,
]) => ExerciseDraft(
  name: name,
  type: type,
  category: category,
  incrementKg: incrementKg,
  // Machines and cables follow the default step of the settings (1.1.0).
  stepMode: _standardStep.contains(name) ? StepMode.standard : StepMode.kg,
);

/// The cable tower with numbered plates (1–15, 4.5 kg each) in the user's
/// gym (1.1.0).
ExerciseDraft _levels(String name, ExerciseCategory category) => ExerciseDraft(
  name: name,
  type: ExerciseType.weightReps,
  category: category,
  incrementKg: _cable,
  stepMode: StepMode.levels,
  levelKg: 4.5,
);

/// Machines with selectorized stacks and cables (not plate-loaded ones like
/// Hackenschmidt). Same list as the 1.1.0 migration of existing exercises.
const _standardStep = {
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
};

/// All exercises of the library, grouped by category.
final List<ExerciseDraft> exerciseLibrary = List.unmodifiable([
  // Brust
  _ex('Bankdrücken', _w, ExerciseCategory.chest, _barbell),
  _ex('Schrägbankdrücken', _w, ExerciseCategory.chest, _barbell),
  _ex('Negativbankdrücken', _w, ExerciseCategory.chest, _barbell),
  _ex('Kurzhantel-Bankdrücken', _w, ExerciseCategory.chest, _dumbbell),
  _ex('Kurzhantel-Schrägbankdrücken', _w, ExerciseCategory.chest, _dumbbell),
  _ex('Kurzhantel-Fliegende', _w, ExerciseCategory.chest, _dumbbell),
  _ex('Brustpresse (Maschine)', _w, ExerciseCategory.chest, _machine),
  _ex('Schräge Brustpresse (Maschine)', _w, ExerciseCategory.chest, _machine),
  _ex('Butterfly (Maschine)', _w, ExerciseCategory.chest, _machine),
  _ex('Cable Crossover', _w, ExerciseCategory.chest, _cable),
  _ex('Überzüge (Kurzhantel)', _w, ExerciseCategory.chest, _dumbbell),
  _ex('Dips', _bw, ExerciseCategory.chest),
  _ex('Liegestütze', _bw, ExerciseCategory.chest),

  // Rücken
  _ex('Kreuzheben', _w, ExerciseCategory.back, _barbell),
  _ex('Klimmzüge', _bw, ExerciseCategory.back),
  _ex('Klimmzüge im Untergriff', _bw, ExerciseCategory.back),
  _ex('Latzug', _w, ExerciseCategory.back, _machine),
  _ex('Latzug eng', _w, ExerciseCategory.back, _machine),
  _ex('Rudern am Kabel (sitzend)', _w, ExerciseCategory.back, _machine),
  _ex('Rudern (Maschine)', _w, ExerciseCategory.back, _machine),
  _ex('Langhantelrudern', _w, ExerciseCategory.back, _barbell),
  _ex('Kurzhantelrudern einarmig', _w, ExerciseCategory.back, _dumbbell),
  _ex('T-Bar-Rudern', _w, ExerciseCategory.back, _barbell),
  _ex('Pullover am Kabel', _w, ExerciseCategory.back, _cable),
  _ex('Rückenstrecker', _bw, ExerciseCategory.back),
  _ex('Rückenstrecker (Maschine)', _w, ExerciseCategory.back, _machine),
  _ex('Shrugs (Kurzhantel)', _w, ExerciseCategory.back, _dumbbell),

  // Beine
  _ex('Kniebeugen', _w, ExerciseCategory.legs, _barbell),
  _ex('Frontkniebeugen', _w, ExerciseCategory.legs, _barbell),
  _ex('Goblet Squats', _w, ExerciseCategory.legs, _dumbbell),
  _ex('Beinpresse', _w, ExerciseCategory.legs, _machine),
  _ex('Hackenschmidt-Kniebeugen', _w, ExerciseCategory.legs, _machine),
  _ex('Beinstrecker (Maschine)', _w, ExerciseCategory.legs, _machine),
  _ex('Beinbeuger liegend (Maschine)', _w, ExerciseCategory.legs, _machine),
  _ex('Beinbeuger sitzend (Maschine)', _w, ExerciseCategory.legs, _machine),
  _ex('Rumänisches Kreuzheben', _w, ExerciseCategory.legs, _barbell),
  _ex('Ausfallschritte (Kurzhantel)', _w, ExerciseCategory.legs, _dumbbell),
  _ex('Bulgarian Split Squats', _w, ExerciseCategory.legs, _dumbbell),
  _ex('Hip Thrust', _w, ExerciseCategory.legs, _barbell),
  _ex('Glute-Kickbacks am Kabel', _w, ExerciseCategory.legs, _cable),
  _ex('Abduktoren (Maschine)', _w, ExerciseCategory.legs, _machine),
  _ex('Adduktoren (Maschine)', _w, ExerciseCategory.legs, _machine),
  _ex('Wadenheben stehend (Maschine)', _w, ExerciseCategory.legs, _machine),
  _ex('Wadenheben sitzend (Maschine)', _w, ExerciseCategory.legs, _machine),
  _ex('Wandsitzen', _t, ExerciseCategory.legs),

  // Schultern
  _ex('Schulterdrücken (Langhantel)', _w, ExerciseCategory.shoulders, _barbell),
  _ex('Kurzhantel-Schulterdrücken', _w, ExerciseCategory.shoulders, _dumbbell),
  _ex('Schulterpresse (Maschine)', _w, ExerciseCategory.shoulders, _machine),
  _ex('Arnold Press', _w, ExerciseCategory.shoulders, _dumbbell),
  _ex('Seitheben (Kurzhantel)', _w, ExerciseCategory.shoulders, _dumbbell),
  _ex('Seitheben am Kabel', _w, ExerciseCategory.shoulders, _cable),
  _ex('Seitheben (Maschine)', _w, ExerciseCategory.shoulders, _machine),
  _ex('Frontheben (Kurzhantel)', _w, ExerciseCategory.shoulders, _dumbbell),
  _ex(
    'Vorgebeugtes Seitheben (Kurzhantel)',
    _w,
    ExerciseCategory.shoulders,
    _dumbbell,
  ),
  _ex('Reverse Butterfly (Maschine)', _w, ExerciseCategory.shoulders, _machine),
  _ex('Face Pulls', _w, ExerciseCategory.shoulders, _cable),
  _ex('Aufrechtes Rudern', _w, ExerciseCategory.shoulders, _barbell),

  // Arme
  _ex('Langhantel-Curls', _w, ExerciseCategory.arms, _barbell),
  _ex('SZ-Curls', _w, ExerciseCategory.arms, _barbell),
  _ex('Kurzhantel-Curls', _w, ExerciseCategory.arms, _dumbbell),
  _ex('Hammer Curls', _w, ExerciseCategory.arms, _dumbbell),
  _ex('Konzentrationscurls', _w, ExerciseCategory.arms, _dumbbell),
  _ex('Scott-Curls (Maschine)', _w, ExerciseCategory.arms, _machine),
  _levels('Bizepscurls am Kabel', ExerciseCategory.arms),
  _levels('Trizepsdrücken am Kabel', ExerciseCategory.arms),
  _levels('Trizepsdrücken über Kopf (Kabel)', ExerciseCategory.arms),
  _ex('French Press (SZ-Stange)', _w, ExerciseCategory.arms, _barbell),
  _ex('Enges Bankdrücken', _w, ExerciseCategory.arms, _barbell),
  _ex('Trizeps-Kickbacks (Kurzhantel)', _w, ExerciseCategory.arms, _dumbbell),
  _ex('Trizeps-Dips (Maschine)', _w, ExerciseCategory.arms, _machine),
  _ex('Bankdips', _bw, ExerciseCategory.arms),
  _ex('Unterarmcurls (Langhantel)', _w, ExerciseCategory.arms, _barbell),

  // Rumpf
  _ex('Plank', _t, ExerciseCategory.core),
  _ex('Seitstütz', _t, ExerciseCategory.core),
  _ex('Hollow Hold', _t, ExerciseCategory.core),
  _ex('Crunches', _bw, ExerciseCategory.core),
  _ex('Sit-ups', _bw, ExerciseCategory.core),
  _ex('Crunches (Maschine)', _w, ExerciseCategory.core, _machine),
  _ex('Crunches am Kabel', _w, ExerciseCategory.core, _cable),
  _ex('Hängendes Beinheben', _bw, ExerciseCategory.core),
  _ex('Beinheben am Dipständer', _bw, ExerciseCategory.core),
  _ex('Russian Twists', _bw, ExerciseCategory.core),
  _ex('Bauchroller', _bw, ExerciseCategory.core),
  _ex('Pallof Press', _w, ExerciseCategory.core, _cable),

  // Ganzkörper
  _ex('Kettlebell Swings', _w, ExerciseCategory.fullBody, _kettlebell),
  _ex('Thruster (Kurzhantel)', _w, ExerciseCategory.fullBody, _dumbbell),
  _ex('Burpees', _bw, ExerciseCategory.fullBody),
  _ex('Farmers Walk', _t, ExerciseCategory.fullBody),

  // Sonstiges: Ausdauergeräte
  _ex('Laufband', _t, ExerciseCategory.other),
  _ex('Crosstrainer', _t, ExerciseCategory.other),
  _ex('Fahrradergometer', _t, ExerciseCategory.other),
  _ex('Rudergerät', _t, ExerciseCategory.other),
  _ex('Stepper', _t, ExerciseCategory.other),
  _ex('Seilspringen', _t, ExerciseCategory.other),
]);

/// Library exercises whose name is not taken yet by any of
/// [existingNames] (case-insensitive, archived exercises included), in
/// library order.
List<ExerciseDraft> missingLibraryExercises(Iterable<String> existingNames) {
  final taken = {for (final n in existingNames) nameKey(n)};
  return [
    for (final e in exerciseLibrary)
      if (!taken.contains(nameKey(e.name))) e,
  ];
}
