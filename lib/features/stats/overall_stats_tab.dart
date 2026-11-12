import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/theme/gym_colors.dart';
import '../../core/theme/typography.dart';
import '../../data/providers.dart';
import '../../domain/body_weight.dart';
import '../../domain/calendar.dart';
import '../../domain/models/models.dart';
import '../../domain/period.dart';
import '../../domain/statistics.dart';
import '../../widgets/charts.dart';
import 'heart_rate_trend_chart.dart';

/// Tab "Gesamt" (SPEC §6.5).
class OverallStatsTab extends StatelessWidget {
  const OverallStatsTab({
    required this.data,
    required this.period,
    required this.today,
    super.key,
  });

  final StatsData data;
  final StatsPeriod period;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    // Shared time axis of the index and the body weight chart.
    final first = data.trainings.first.day;
    final start = period.startFor(today);
    final from = start == null || first.isAfter(start)
        ? mondayOf(first)
        : start;
    final minX = dayX(from);
    final maxX = dayX(today);

    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      children: [
        _StrengthIndexChart(
          points: [
            for (final p in strengthIndex(data, today))
              if (!p.monday.addDays(6).isBefore(from)) p,
          ],
          minX: minX,
          maxX: maxX,
        ),
        // Second place on purpose (1.0.1).
        _StreakCard(
          current: currentStreak(data, today),
          longest: longestStreak(data),
          trainedThisWeek: data.trainings.any(
            (t) => !t.day.isBefore(mondayOf(today)),
          ),
        ),
        // Always shown (1.0.1); shares the time axis with the index.
        _BodyWeightChart(
          data: [
            for (final s in movingAverage7(data.bodyWeights))
              if (!s.entry.date.isBefore(from) && !s.entry.date.isAfter(today))
                s,
          ],
          minX: minX,
          maxX: maxX,
        ),
        _TrainingVolumeChart(
          trainings: [
            for (final t in trainingVolumes(data))
              if (!t.day.isBefore(from)) t,
          ],
        ),
        // 1.5.1: only with a heart rate monitor.
        HeartRateTrendChart(
          title: S.heartRateTrainingTrend,
          info: S.heartRateTrainingTrendInfo,
          maxLabel: S.heartRateLegendMax,
          points: [
            for (final p in trainingHeartRates(data))
              if (!p.day.isBefore(from)) p,
          ],
        ),
        // 1.6.0: recovery, weekly load, calories.
        Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(settingsProvider).value;
            final threshold = settings?.hrThreshold;
            return Column(
              children: [
                ValueTrendChart(
                  title: S.heartRateRecovery,
                  info: S.heartRateRecoveryInfo,
                  unit: S.unitBpm,
                  points: [
                    for (final p in trainingRecoveries(data))
                      if (!p.day.isBefore(from)) p,
                  ],
                ),
                if (threshold != null)
                  WeeklyBarsChart(
                    title: S.weeklyLoad,
                    info: S.weeklyLoadInfo,
                    unit: S.weeklyLoadUnit,
                    weeks: [
                      for (final w in weeklyLoad(data, today, threshold))
                        if (!w.monday.addDays(6).isBefore(from)) w,
                    ],
                  ),
                if (settings != null)
                  WeeklyBarsChart(
                    title: S.weeklyCalories,
                    info: S.caloriesWeekInfo,
                    unit: 'kcal',
                    weeks: [
                      for (final w in weeklyCalories(data, today, settings))
                        if (!w.monday.addDays(6).isBefore(from)) w,
                    ],
                  ),
              ],
            );
          },
        ),
        _Heatmap(
          grid: trainingHeatmap(data, today),
          perWeek: trainingsPerWeek(data, period, today),
        ),
        _DurationChart(
          trainings: [
            for (final t in data.trainings)
              if (period.contains(t.day, today)) t,
          ],
        ),
        _CategoryBars(counts: setsPerCategory(data, period, today)),
      ],
    );
  }
}

class _StrengthIndexChart extends StatelessWidget {
  const _StrengthIndexChart({
    required this.points,
    required this.minX,
    required this.maxX,
  });

  final List<IndexPoint> points;
  final double minX;
  final double maxX;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    if (points.isEmpty) {
      return const ChartCard(
        title: S.strengthIndex,
        info: S.strengthIndexInfo,
        height: 120,
        child: ChartEmpty(S.strengthIndexEmpty),
      );
    }
    final spots = [for (final p in points) FlSpot(dayX(p.monday), p.percent)];
    final ys = [100.0, ...spots.map((s) => s.y)];
    final lo = ys.reduce((a, b) => a < b ? a : b);
    final hi = ys.reduce((a, b) => a > b ? a : b);
    return ChartCard(
      title: S.strengthIndex,
      info: S.strengthIndexInfo,
      subtitle: S.strengthIndexSubtitle(points.last.exerciseCount),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: ((lo - 5) / 5).floorToDouble() * 5,
          maxY: ((hi + 5) / 5).ceilToDouble() * 5,
          clipData: const FlClipData.all(),
          gridData: chartGrid(context),
          borderData: FlBorderData(show: false),
          titlesData: dayTitles(
            context,
            minX: minX,
            maxX: maxX,
            formatY: (v) => '${v.round()} %',
            reservedLeft: 48,
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 100,
                color: theme.colorScheme.outline,
                strokeWidth: 1.5,
                dashArray: const [6, 4],
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: lineTooltip(
              context,
              (touched) => [
                for (final t in touched)
                  LineTooltipItem(
                    '${formatShortDate(dayFromX(t.x).toLocalDateTime())}: '
                    '${t.y.round()} %\n'
                    '${S.strengthIndexSubtitle(points[t.spotIndex].exerciseCount)}',
                    TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              barWidth: 3,
              color: gym.activeEdge,
              dotData: FlDotData(show: spots.length < 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyWeightChart extends StatelessWidget {
  const _BodyWeightChart({
    required this.data,
    required this.minX,
    required this.maxX,
  });

  final List<SmoothedWeight> data;
  final double minX;
  final double maxX;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return const ChartCard(
        title: S.tabBody,
        height: 100,
        child: ChartEmpty(S.bodyWeightChartEmpty),
      );
    }
    final ys = data.map((s) => s.entry.weightKg);
    return ChartCard(
      title: S.tabBody,
      subtitle: S.average7,
      height: 160,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: (ys.reduce((a, b) => a < b ? a : b) - 0.5).floorToDouble(),
          maxY: (ys.reduce((a, b) => a > b ? a : b) + 0.5).ceilToDouble(),
          gridData: chartGrid(context),
          borderData: FlBorderData(show: false),
          titlesData: dayTitles(
            context,
            minX: minX,
            maxX: maxX,
            formatY: (v) => v.toStringAsFixed(0),
            reservedLeft: 48,
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: lineTooltip(
              context,
              (touched) => [
                for (final t in touched)
                  LineTooltipItem(
                    '${formatShortDate(dayFromX(t.x).toLocalDateTime())}: '
                    '${formatKg1(t.y)}',
                    TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final s in data) FlSpot(dayX(s.entry.date), s.average),
              ],
              barWidth: 3,
              isCurved: true,
              preventCurveOverShooting: true,
              color: theme.colorScheme.onSurfaceVariant,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

final _int = NumberFormat.decimalPattern(appLocale);

/// One bar per training, side by side (1.3.1).
class _TrainingVolumeChart extends StatelessWidget {
  const _TrainingVolumeChart({required this.trainings});

  final List<TrainingVolume> trainings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    if (trainings.isEmpty) {
      return const ChartCard(
        title: S.trainingVolume,
        info: S.trainingVolumeInfo,
        height: 100,
        child: ChartEmpty(S.volumeEmpty),
      );
    }
    final labelEvery = (trainings.length / 4).ceil().clamp(1, 1000);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ChartCard(
      title: S.trainingVolume,
      info: S.trainingVolumeInfo,
      subtitle: S.unitKg,
      child: BarChart(
        BarChartData(
          gridData: chartGrid(context),
          borderData: FlBorderData(show: false),
          alignment: BarChartAlignment.spaceBetween,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${formatShortDate(trainings[groupIndex].day.toLocalDateTime())}'
                '${trainings[groupIndex].planName == null ? '' : ' · ${trainings[groupIndex].planName}'}\n'
                '${_int.format(rod.toY.round())} ${S.unitKg}',
                TextStyle(color: theme.colorScheme.onInverseSurface),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    value >= 1000
                        ? '${NumberFormat('#,##0.#', appLocale).format(value / 1000)}k'
                        : _int.format(value.round()),
                    style: style,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i % labelEvery != 0 || i >= trainings.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      formatShortDate(trainings[i].day.toLocalDateTime()),
                      style: style,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (final (i, t) in trainings.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: t.value,
                    color: gym.activeEdge,
                    width: (240 / trainings.length).clamp(2.0, 14.0),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.grid, required this.perWeek});

  /// `[week][weekday]` sets, oldest week first.
  final List<List<int>> grid;
  final double perWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final max = grid.expand((w) => w).fold(0, (a, b) => a > b ? a : b);
    Color colorFor(int sets) {
      if (sets == 0) return scheme.surfaceContainerHighest;
      final level = max == 0 ? 1.0 : (sets / max).clamp(0.25, 1.0);
      return Color.lerp(scheme.primaryContainer, scheme.primary, level)!;
    }

    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return ChartCard(
      title: S.calendar,
      info: S.calendarInfo,
      subtitle: S.calendarSubtitle,
      height: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const labelWidth = 24.0;
              const gap = 2.0;
              final cell = ((constraints.maxWidth - labelWidth) / grid.length)
                  .clamp(4.0, 20.0);
              final height = cell * 7;
              return SizedBox(
                height: height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Column(
                        children: [
                          for (final (i, d) in S.weekdayInitials.indexed)
                            SizedBox(
                              height: cell,
                              child: i.isEven
                                  ? FittedBox(child: Text(d, style: labelStyle))
                                  : null,
                            ),
                        ],
                      ),
                    ),
                    for (final week in grid)
                      Column(
                        children: [
                          for (final sets in week)
                            Container(
                              width: cell - gap,
                              height: cell - gap,
                              margin: const EdgeInsets.all(gap / 2),
                              decoration: BoxDecoration(
                                color: colorFor(sets),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            S.perWeek(formatDecimal1(perWeek)),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Weeks in a row with training, highlighted (1.0.1); the longest streak
/// is shown as "nicht aktiv" when the current one is shorter.
class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.current,
    required this.longest,
    required this.trainedThisWeek,
  });

  final int current;
  final int longest;
  final bool trainedThisWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final active = current > 0;
    final hints = [
      if (active && current == longest && longest > 1) S.streakIsLongest,
      if (longest > current) S.streakLongest(longest),
      if (!trainedThisWeek) active ? S.streakKeep : S.streakStart,
    ];
    return ChartCard(
      title: S.streakTitle,
      info: S.streakInfo,
      height: null,
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department,
            size: 44,
            color: active ? gym.superset : muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (active)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$current ',
                          style: NumberStyles.small.copyWith(
                            fontSize: 40,
                            height: 1.1,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: S.streakWeeksLabel(current),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    S.streakNone,
                    style: theme.textTheme.titleLarge?.copyWith(color: muted),
                  ),
                for (final h in hints)
                  Text(
                    h,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationChart extends StatelessWidget {
  const _DurationChart({required this.trainings});

  final List<Training> trainings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    if (trainings.length < 2) {
      return const ChartCard(
        title: S.trainingDuration,
        height: 100,
        child: ChartEmpty(S.durationEmpty),
      );
    }
    final spots = [
      for (final t in trainings)
        FlSpot(
          dayX(t.day),
          t.session.endedAt!
              .difference(t.session.startedAt)
              .inMinutes
              .toDouble(),
        ),
    ];
    final hi = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    return ChartCard(
      title: S.trainingDuration,
      subtitle: S.minutesUnit,
      height: 180,
      child: LineChart(
        LineChartData(
          minX: spots.first.x,
          maxX: spots.last.x,
          minY: 0,
          maxY: ((hi + 10) / 10).ceilToDouble() * 10,
          gridData: chartGrid(context),
          borderData: FlBorderData(show: false),
          titlesData: dayTitles(
            context,
            minX: spots.first.x,
            maxX: spots.last.x,
            formatY: (v) => '${v.round()}',
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: lineTooltip(
              context,
              (touched) => [
                for (final t in touched)
                  LineTooltipItem(
                    '${formatShortDate(dayFromX(t.x).toLocalDateTime())}: '
                    '${S.minutes(t.y.round())}',
                    TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              barWidth: 0,
              color: Colors.transparent,
              dotData: FlDotData(
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 3.5,
                      color: gym.activeEdge,
                      strokeWidth: 0,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.counts});

  final Map<ExerciseCategory?, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return const ChartCard(
        title: S.setsPerCategory,
        height: 80,
        child: ChartEmpty(S.categoryEmpty),
      );
    }
    final max = entries.first.value;
    final scaler = MediaQuery.textScalerOf(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(S.setsPerCategory, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      // Grows with the system font, but leaves room for
                      // the bars (M10).
                      width: scaler.scale(90).clamp(90, 140),
                      child: Text(
                        S.category(e.key),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 14,
                            width: c.maxWidth * e.value / max,
                            decoration: BoxDecoration(
                              color: gym.activeEdge,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: scaler.scale(40),
                      child: Text(
                        '${e.value}',
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
