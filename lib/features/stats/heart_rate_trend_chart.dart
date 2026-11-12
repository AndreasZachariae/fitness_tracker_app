import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/theme/gym_colors.dart';
import '../../domain/statistics.dart';
import '../../widgets/charts.dart';

/// Average and maximum heart rate over time (1.5.1): per training in the
/// overall tab, per exercise in the exercise tab. Nothing without values.
class HeartRateTrendChart extends StatelessWidget {
  const HeartRateTrendChart({
    required this.title,
    required this.info,
    required this.maxLabel,
    required this.points,
    super.key,
  });

  final String title;
  final String info;

  /// "Max." or "Spitze".
  final String maxLabel;
  final List<HeartRateTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final avg = [
      for (final p in points) FlSpot(dayX(p.day), p.average.toDouble()),
    ];
    final max = [for (final p in points) FlSpot(dayX(p.day), p.max.toDouble())];
    final lo = points.map((p) => p.average).reduce((a, b) => a < b ? a : b);
    final hi = points.map((p) => p.max).reduce((a, b) => a > b ? a : b);
    final minX = avg.first.x;
    final maxX = avg.last.x == minX ? minX + 1 : avg.last.x;
    final avgColor = gym.record;
    final maxColor = gym.record.withValues(alpha: 0.45);
    return ChartCard(
      key: ValueKey('heart-rate-trend-$title'),
      title: title,
      subtitle: '${S.heartRateLegendAverage} · $maxLabel',
      info: info,
      height: 180,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: ((lo - 10) / 10).floorToDouble() * 10,
          maxY: ((hi + 10) / 10).ceilToDouble() * 10,
          clipData: const FlClipData.all(),
          gridData: chartGrid(context),
          borderData: FlBorderData(show: false),
          titlesData: dayTitles(
            context,
            minX: minX,
            maxX: maxX,
            formatY: (v) => '${v.round()}',
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: lineTooltip(context, (touched) {
              return [
                for (final t in touched)
                  LineTooltipItem(
                    '${t.barIndex == 0 ? S.heartRateLegendAverage : maxLabel}: '
                    '${t.y.round()} ${S.unitBpm}'
                    '${t.barIndex == 0 ? '' : '\n${formatShortDate(points[t.spotIndex].day.toLocalDateTime())}'}',
                    TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
              ];
            }),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: avg,
              barWidth: 3,
              color: avgColor,
              dotData: FlDotData(show: points.length < 15),
            ),
            LineChartBarData(
              spots: max,
              barWidth: 2,
              color: maxColor,
              dashArray: const [6, 4],
              dotData: FlDotData(show: points.length < 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// One value per training over time, e.g. the heart rate recovery (1.6.0).
class ValueTrendChart extends StatelessWidget {
  const ValueTrendChart({
    required this.title,
    required this.info,
    required this.points,
    required this.unit,
    super.key,
  });

  final String title;
  final String info;
  final String unit;
  final List<DayValue> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final spots = [for (final p in points) FlSpot(dayX(p.day), p.value)];
    final lo = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final hi = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final minX = spots.first.x;
    final maxX = spots.last.x == minX ? minX + 1 : spots.last.x;
    return ChartCard(
      key: ValueKey('value-trend-$title'),
      title: title,
      subtitle: unit,
      info: info,
      height: 170,
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
            formatY: (v) => '${v.round()}',
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: lineTooltip(context, (touched) {
              return [
                for (final t in touched)
                  LineTooltipItem(
                    '${formatShortDate(points[t.spotIndex].day.toLocalDateTime())}: '
                    '${t.y.round()} $unit',
                    TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
              ];
            }),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              barWidth: 3,
              color: theme.colorScheme.primary,
              dotData: FlDotData(show: points.length < 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bar per week, e.g. training load or calories (1.6.0).
class WeeklyBarsChart extends StatelessWidget {
  const WeeklyBarsChart({
    required this.title,
    required this.info,
    required this.unit,
    required this.weeks,
    super.key,
  });

  final String title;
  final String info;
  final String unit;
  final List<WeekSum> weeks;

  @override
  Widget build(BuildContext context) {
    if (weeks.every((w) => w.value == 0)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final labelEvery = (weeks.length / 4).ceil().clamp(1, 1000);
    return ChartCard(
      key: ValueKey('weekly-bars-$title'),
      title: title,
      subtitle: unit,
      info: info,
      height: 170,
      child: BarChart(
        BarChartData(
          gridData: chartGrid(context),
          borderData: FlBorderData(show: false),
          alignment: BarChartAlignment.spaceBetween,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${S.weekOf(formatShortDate(weeks[groupIndex].monday.toLocalDateTime()))}: '
                '${rod.toY.round()} $unit',
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
                reservedSize: 40,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text('${v.round()}', style: style),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
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
                    width: (240 / weeks.length).clamp(3.0, 16.0),
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
