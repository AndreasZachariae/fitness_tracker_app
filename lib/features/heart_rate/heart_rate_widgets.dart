import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings_de.dart';
import '../../core/theme/gym_colors.dart';
import '../../data/providers.dart';
import '../../domain/heart_rate.dart';
import '../../widgets/charts.dart';
import 'heart_rate_recorder.dart';

/// "♥ 128" in the head of the training (1.5.0); nothing without a monitor.
class HeartRateIndicator extends ConsumerWidget {
  const HeartRateIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(heartRateLiveProvider);
    if (live.status == HeartRateStatus.off) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final connected = live.status == HeartRateStatus.connected;
    final color = connected
        ? GymColors.of(context).record
        : theme.colorScheme.onSurfaceVariant;
    final status = switch (live.status) {
      HeartRateStatus.connected => '${live.bpm} ${S.unitBpm}',
      HeartRateStatus.connecting => S.heartRateStatusConnecting,
      HeartRateStatus.reconnecting => S.heartRateStatusLost,
      HeartRateStatus.unavailable => S.heartRateStatusUnavailable,
      HeartRateStatus.off => '',
    };
    return Tooltip(
      message: S.heartRateLiveLabel(status),
      child: Semantics(
        label: S.heartRateLiveLabel(status),
        excludeSemantics: true,
        child: Row(
          key: const ValueKey('heart-rate-indicator'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connected ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              connected && live.bpm != null ? '${live.bpm}' : '–',
              style: theme.textTheme.titleMedium?.copyWith(
                color: connected ? theme.colorScheme.onSurface : color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Average, maximum and the curve of a training (1.5.0); nothing if the
/// training has no heart rate.
class HeartRateSection extends ConsumerWidget {
  const HeartRateSection({
    required this.sessionId,
    required this.start,
    super.key,
  });

  final int sessionId;
  final DateTime start;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final samples =
        ref.watch(heartRateSamplesProvider(sessionId)).value ?? const [];
    final stats = heartRateStats(samples);
    if (stats == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final points = heartRateCurve(samples, start);
    final lo = (stats.min - 10).clamp(minBpm, maxBpm).toDouble();
    final hi = (stats.max + 10).clamp(minBpm, maxBpm).toDouble();
    final maxX = points.last.minutes <= 0 ? 1.0 : points.last.minutes;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ChartCard(
      key: const ValueKey('heart-rate-section'),
      title: S.heartRate,
      subtitle: S.heartRateSummary(stats.average, stats.max),
      info: S.heartRateInfo,
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: lo,
          maxY: hi,
          clipData: const FlClipData.all(),
          gridData: chartGrid(context),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
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
                interval: maxX <= 4 ? 1 : (maxX / 4).ceilToDouble(),
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text('${v.round()} min', style: style),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: lineTooltip(context, (touched) {
              return [
                for (final t in touched)
                  LineTooltipItem(
                    '${t.y.round()} ${S.unitBpm} · ${t.x.round()} min',
                    TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
              ];
            }),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (final p in points) FlSpot(p.minutes, p.bpm)],
              barWidth: 2,
              color: gym.record,
              dotData: const FlDotData(show: false),
              isCurved: false,
            ),
          ],
        ),
      ),
    );
  }
}
