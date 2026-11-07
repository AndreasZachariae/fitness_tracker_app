import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/format/exercise_format.dart';
import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/theme/gym_colors.dart';
import '../../core/theme/typography.dart';
import '../../domain/models/models.dart';
import '../../domain/names.dart';
import '../../domain/period.dart';
import '../../domain/statistics.dart';
import '../../domain/weight_steps.dart';
import '../../widgets/charts.dart';
import '../../widgets/exercise_type_icon.dart';
import '../../widgets/info_button.dart';
import 'metric_format.dart';

/// Tab "Übung": one exercise, one metric, one point per training.
class ExerciseStatsTab extends StatelessWidget {
  const ExerciseStatsTab({
    required this.data,
    required this.period,
    required this.today,
    required this.exerciseId,
    required this.metrics,
    required this.onExercise,
    required this.onMetric,
    super.key,
  });

  final StatsData data;
  final StatsPeriod period;
  final LocalDate today;
  final int? exerciseId;
  final Map<int, ExerciseMetric> metrics;
  final ValueChanged<int> onExercise;
  final void Function(int exerciseId, ExerciseMetric metric) onMetric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercises = exercisesWithData(data);
    final exercise = exercises.firstWhere(
      (e) => e.id == exerciseId,
      orElse: () => exercises.first,
    );
    final available = metricsFor(
      exercise.type,
      hasBodyWeights: data.hasBodyWeights,
    );
    final metric = available.contains(metrics[exercise.id])
        ? metrics[exercise.id]!
        : available.first;
    final series = exerciseSeries(data, exercise.id, metric);
    final shown = [
      for (final p in series)
        if (period.contains(p.day, today)) p,
    ];
    final summary = summarizeSeries(shown);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(56),
            ),
            icon: ExerciseTypeIcon(exercise.type),
            label: Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.expand_more),
              ],
            ),
            onPressed: () async {
              final picked = await _pickExercise(context, exercises);
              if (picked != null) onExercise(picked);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final m in available)
                      ChoiceChip(
                        label: Text(S.metric(m)),
                        selected: m == metric,
                        onSelected: (_) => onMetric(exercise.id, m),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InfoButton(
                  title: S.metric(metric),
                  text: S.metricInfo(metric),
                ),
              ),
            ],
          ),
        ),
        _SeriesChart(
          points: shown,
          metric: metric,
          type: exercise.type,
          levels: levelsOf(exercise),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Figure(
                    label: S.statBest,
                    value: summary.best == null
                        ? '–'
                        : formatMetric(
                            metric,
                            summary.best!,
                            levels: !storesKg(exercise),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Figure(
                    label: S.statChange,
                    value: summary.change == null
                        ? '–'
                        : formatMetricChange(
                            metric,
                            summary.change!,
                            summary.changePercent,
                            levels: !storesKg(exercise),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Figure(
                    label: S.statTrainings,
                    value: '${summary.count}',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (shown.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(S.lastTrainings, style: theme.textTheme.titleMedium),
          ),
          for (final p in shown.reversed.take(10))
            ListTile(
              dense: true,
              title: Text(
                formatWeekdayDate(p.training.session.startedAt),
                style: theme.textTheme.bodyLarge,
              ),
              subtitle: Text(
                formatSetsDetailed(
                  exercise.type,
                  p.sets,
                  levels: levelsOf(exercise),
                ),
              ),
              trailing: Text(
                formatMetric(metric, p.value, levels: !storesKg(exercise)),
                style: NumberStyles.small.copyWith(
                  fontSize: 18,
                  color: p.isRecord
                      ? GymColors.of(context).record
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

Future<int?> _pickExercise(BuildContext context, List<Exercise> exercises) =>
    showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _ExercisePicker(exercises: exercises),
      ),
    );

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({required this.exercises});

  final List<Exercise> exercises;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final list = [
      for (final e in widget.exercises)
        if (sortKey(e.name).contains(sortKey(_query))) e,
    ]..sort((a, b) => compareNames(a.name, b.name));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: S.chooseExercise,
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final e in list)
                ListTile(
                  leading: ExerciseTypeIcon(e.type),
                  title: Text(e.name),
                  onTap: () => Navigator.of(context).pop(e.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeriesChart extends StatelessWidget {
  const _SeriesChart({
    required this.points,
    required this.metric,
    required this.type,
    required this.levels,
  });

  final List<SeriesPoint> points;
  final ExerciseMetric metric;
  final ExerciseType type;
  final LevelStep? levels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    if (points.length < 2) {
      return ChartCard(
        title: S.metric(metric),
        height: 120,
        child: const ChartEmpty(S.statsSeriesEmpty),
      );
    }
    final spots = [for (final p in points) FlSpot(dayX(p.day), p.value)];
    final values = points.map((p) => p.value);
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final pad = ((hi - lo) * 0.15).clamp(1.0, double.infinity);
    return ChartCard(
      title: S.metric(metric),
      child: LineChart(
        LineChartData(
          minX: spots.first.x,
          maxX: spots.last.x,
          minY: (lo - pad).clamp(0, double.infinity).floorToDouble(),
          maxY: (hi + pad).ceilToDouble(),
          gridData: chartGrid(context),
          borderData: FlBorderData(show: false),
          titlesData: dayTitles(
            context,
            minX: spots.first.x,
            maxX: spots.last.x,
            formatY: (v) => formatAxis(metric, v),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: lineTooltip(context, (touched) {
              return [
                for (final t in touched)
                  LineTooltipItem(
                    '${formatShortDate(points[t.spotIndex].training.session.startedAt)}: '
                    '${formatMetric(metric, t.y, levels: levels != null && levels!.kgPerLevel == null)}\n'
                    '${formatSetsDetailed(type, points[t.spotIndex].sets, levels: levels)}',
                    TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
              ];
            }),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              barWidth: 3,
              color: gym.activeEdge,
              dotData: FlDotData(
                getDotPainter: (spot, percent, bar, index) {
                  final record = points[index].isRecord;
                  return FlDotCirclePainter(
                    radius: record ? 5 : 3,
                    color: record ? gym.record : gym.activeEdge,
                    strokeWidth: record ? 2 : 0,
                    strokeColor: theme.colorScheme.surface,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: NumberStyles.small.copyWith(
                fontSize: 17,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
