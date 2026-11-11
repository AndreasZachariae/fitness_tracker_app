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
