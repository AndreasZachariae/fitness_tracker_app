import 'package:flutter/material.dart';

import '../core/l10n/strings_de.dart';
import '../domain/models/enums.dart';

/// Icon of an exercise type, with the type name for screen readers.
class ExerciseTypeIcon extends StatelessWidget {
  const ExerciseTypeIcon(this.type, {this.color, super.key});

  final ExerciseType type;
  final Color? color;

  static IconData iconFor(ExerciseType type) => switch (type) {
    ExerciseType.weightReps => Icons.fitness_center,
    ExerciseType.bodyweight => Icons.accessibility_new,
    ExerciseType.timed => Icons.timer_outlined,
  };

  @override
  Widget build(BuildContext context) => Icon(
    iconFor(type),
    color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    semanticLabel: S.exerciseType(type),
  );
}
