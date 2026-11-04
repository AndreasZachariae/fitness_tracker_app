import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/theme/gym_colors.dart';
import '../../domain/body_weight.dart';
import '../../domain/calendar.dart';
import '../../domain/models/models.dart';
import '../../domain/period.dart';
import '../../domain/statistics.dart';
import '../../widgets/charts.dart';

/// Tab "Gesamt" (SPEC §6.5).
class OverallStatsTab extends StatelessWidget {
  const OverallStatsTab({
    required this.data,
    required this.period,
    required this.today,
    required this.showBodyWeight,
    required this.onShowBodyWeight,
    super.key,
  });

  final StatsData data;
  final StatsPeriod period;
  final LocalDate today;
  final bool showBodyWeight;
  final ValueChanged<bool> onShowBodyWeight;

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text(S.showBodyWeight),
            value: showBodyWeight,
            onChanged: onShowBodyWeight,
          ),
        ),
        if (showBodyWeight)
          _BodyWeightChart(
            data: [
              for (final s in movingAverage7(data.bodyWeights))
                if (!s.entry.date.isBefore(from) &&
                    !s.entry.date.isAfter(today))
                  s,
            ],
            minX: minX,
            maxX: maxX,
          ),
        _WeeklyVolumeChart(
          weeks: [
            for (final w in weeklyVolume(data, today))
              if (!w.monday.addDays(6).isBefore(from)) w,
          ],
        ),
        _Heatmap(
          grid: trainingHeatmap(data, today),
          perWeek: trainingsPerWeek(data, period, today),
          streak: currentStreak(data, today),
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

class _WeeklyVolumeChart extends StatelessWidget {
  const _WeeklyVolumeChart({required this.weeks});

  final List<WeekValue> weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    if (weeks.every((w) => w.value == 0)) {
      return const ChartCard(
        title: S.weeklyVolume,
        info: S.weeklyVolumeInfo,
        height: 100,
        child: ChartEmpty(S.volumeEmpty),
      );
    }
    final labelEvery = (weeks.length / 4).ceil().clamp(1, 1000);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ChartCard(
      title: S.weeklyVolume,
      info: S.weeklyVolumeInfo,
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
                '${formatShortDate(weeks[groupIndex].monday.toLocalDateTime())}: '
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
                  if (i % labelEvery != 0 || i >= weeks.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      formatShortDate(weeks[i].monday.toLocalDateTime()),
                      style: style,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (final (i, w) in weeks.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: w.value,
                    color: gym.activeEdge,
                    width: (240 / weeks.length).clamp(2.0, 14.0),
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
  const _Heatmap({
    required this.grid,
    required this.perWeek,
    required this.streak,
  });

  /// `[week][weekday]` sets, oldest week first.
  final List<List<int>> grid;
  final double perWeek;
  final int streak;

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
          Text(S.streak(streak), style: theme.textTheme.bodyMedium),
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
