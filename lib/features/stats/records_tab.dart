import 'package:flutter/material.dart';

import '../../core/format/exercise_format.dart';
import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/theme/gym_colors.dart';
import '../../domain/names.dart';
import '../../domain/statistics.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/exercise_type_icon.dart';

/// Tab "Rekorde": best values of every exercise; tap → tab "Übung".
class RecordsTab extends StatelessWidget {
  const RecordsTab({required this.data, required this.onTap, super.key});

  final StatsData data;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final records = recordsOverview(data, compareNames);
    if (records.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events_outlined,
        message: S.recordsEmpty,
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final (exercise, best) in records)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onTap(exercise.id),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExerciseTypeIcon(exercise.type),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.name,
                            style: theme.textTheme.titleMedium,
                          ),
                          for (final b in best)
                            Text(
                              '${S.recordKind(b.kind)}: '
                              '${formatRecordValue(b.kind, b.value)} · '
                              '${formatShortDate(b.day.toLocalDateTime())}',
                              style: theme.textTheme.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.emoji_events, color: gym.record, size: 20),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
