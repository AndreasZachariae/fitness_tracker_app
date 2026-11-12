import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/theme/gym_colors.dart';
import '../../data/providers.dart';
import '../../domain/heart_rate.dart';
import '../../domain/heart_rate_zones.dart';
import '../../domain/statistics.dart';
import '../../widgets/charts.dart';
import '../../widgets/info_button.dart';
import 'heart_rate_recorder.dart';
import 'zone_colors.dart';

/// "♥ 128" (1.5.0); since 1.5.1 in the active exercise and larger with
/// [large]. Nothing without a chosen monitor or training; "♥ –" in grey
/// while (re)connecting.
class HeartRateIndicator extends ConsumerWidget {
  const HeartRateIndicator({this.large = false, super.key});

  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(heartRateLiveProvider);
    if (live.status == HeartRateStatus.off) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).value;
    final connected = live.status == HeartRateStatus.connected;
    final bpm = live.bpm;
    final threshold = settings?.hrThreshold;
    // 1.6.0: Garmin's color of the range; red above the warning limit.
    final warn =
        connected &&
        bpm != null &&
        settings?.hrWarnBpm != null &&
        bpm >= settings!.hrWarnBpm!;
    final color = !connected || bpm == null
        ? theme.colorScheme.onSurfaceVariant
        : threshold != null
        ? zoneColor(zoneOf(bpm, threshold))
        : GymColors.of(context).record;
    final status = switch (live.status) {
      HeartRateStatus.connected => '${live.bpm} ${S.unitBpm}',
      HeartRateStatus.connecting => S.heartRateStatusConnecting,
      HeartRateStatus.reconnecting => S.heartRateStatusLost,
      HeartRateStatus.unavailable => S.heartRateStatusUnavailable,
      HeartRateStatus.off => '',
    };
    final text =
        (large ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)
            ?.copyWith(
              color: connected ? theme.colorScheme.onSurface : color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            );
    return Tooltip(
      message: S.heartRateLiveLabel(status),
      child: Semantics(
        label: S.heartRateLiveLabel(status),
        excludeSemantics: true,
        child: Container(
          key: const ValueKey('heart-rate-indicator'),
          padding: warn
              ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
              : EdgeInsets.zero,
          decoration: warn
              ? BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Row(
            key: warn ? const ValueKey('heart-rate-warning') : null,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                connected ? Icons.favorite : Icons.favorite_border,
                size: large ? 26 : 20,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                connected && live.bpm != null ? '${live.bpm}' : '–',
                style: text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "♥ 142" in a set row: the peak of the set (1.5.1).
class SetHeartRateLabel extends StatelessWidget {
  const SetHeartRateLabel({required this.peak, super.key});

  final int peak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: S.heartRateSetPeak(peak),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite, size: 14, color: GymColors.of(context).record),
          const SizedBox(width: 2),
          Text(
            '$peak',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The heart rate of a finished training (1.5.0, since 1.5.1 from the kept
/// summary): average and maximum, the curve (one value per minute), a violin
/// plot against earlier trainings of the same plan and the peak per
/// exercise. Nothing if the training has no heart rate.
class HeartRateSection extends ConsumerWidget {
  const HeartRateSection({required this.sessionId, super.key});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(sessionHeartRateProvider(sessionId)).value;
    if (summary == null) return const SizedBox.shrink();
    final earlier =
        ref.watch(earlierHeartRateProvider(sessionId)).value ?? const {};
    final details =
        ref.watch(sessionDetailsProvider(sessionId)).value ?? const [];
    final perExercise = [
      for (final d in details)
        if (d.sessionExercise.hrMax case final max?) (d.exercise.name, max),
    ];
    // 1.6.0: zones, recovery, calories.
    final settings = ref.watch(settingsProvider).value;
    final session = ref.watch(sessionProvider(sessionId)).value;
    final weights = ref.watch(bodyWeightsProvider).value ?? const [];
    final sortedWeights = [...weights]
      ..sort((a, b) => a.date.compareTo(b.date));
    final threshold = settings?.hrThreshold;
    final calories = settings == null || session == null
        ? null
        : trainingCalories(summary, session.startedAt, sortedWeights, settings);
    return Column(
      key: const ValueKey('heart-rate-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CurveCard(
          curve: summary.perMinute,
          average: summary.avgBpm,
          max: summary.maxBpm,
          min: summary.minBpm,
        ),
        if (threshold != null)
          _ZonesCard(seconds: secondsPerZone(summary.distribution, threshold)),
        _FiguresCard(
          recovery: summary.recoveryBpm,
          calories: calories,
          caloriesMissing: settings?.birthYear == null || settings?.sex == null,
        ),
        _ViolinCard(
          current: summary.distribution,
          earlier: earlier,
          max: summary.maxBpm,
        ),
        if (perExercise.isNotEmpty) _PeaksCard(peaks: perExercise),
      ],
    );
  }
}

class _CurveCard extends StatelessWidget {
  const _CurveCard({
    required this.curve,
    required this.average,
    required this.max,
    required this.min,
  });

  final List<int?> curve;
  final int average;
  final int max;
  final int min;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final spots = [
      for (final (i, v) in curve.indexed)
        v == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), v.toDouble()),
    ];
    final lo = (min - 10).clamp(minBpm, maxBpm).toDouble();
    final hi = (max + 10).clamp(minBpm, maxBpm).toDouble();
    final maxX = curve.length <= 1 ? 1.0 : (curve.length - 1).toDouble();
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ChartCard(
      title: S.heartRate,
      subtitle: S.heartRateSummary(average, max),
      info: S.heartRateInfo,
      height: 180,
      margin: const EdgeInsets.symmetric(vertical: 6),
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
              spots: spots,
              barWidth: 2,
              color: gym.record,
              dotData: FlDotData(show: curve.length < 3),
            ),
          ],
        ),
      ),
    );
  }
}

/// This training's distribution next to the average of earlier ones.
class _ViolinCard extends StatelessWidget {
  const _ViolinCard({
    required this.current,
    required this.earlier,
    required this.max,
  });

  final Map<int, int> current;
  final Map<int, double> earlier;

  /// This training's highest heart rate, marked in its violin (1.6.1).
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final now = normalizeHistogram(current);
    final keys = [...now.keys, ...earlier.keys];
    if (keys.isEmpty) return const SizedBox.shrink();
    final lo = (keys.reduce((a, b) => a < b ? a : b) - 8).clamp(minBpm, maxBpm);
    final hi = (keys.reduce((a, b) => a > b ? a : b) + 8).clamp(minBpm, maxBpm);
    final violins = [
      (
        label: S.heartRateThisTraining,
        shape: violinShape(now, from: lo, to: hi),
        quartiles: quartilesOf(now),
        color: gym.record,
        max: max,
      ),
      if (earlier.isNotEmpty)
        (
          label: S.heartRateEarlier,
          shape: violinShape(earlier, from: lo, to: hi),
          quartiles: quartilesOf(earlier),
          color: theme.colorScheme.onSurfaceVariant,
          max: null,
        ),
    ];
    return ChartCard(
      title: S.heartRateDistribution,
      info: S.heartRateDistributionInfo,
      height: 220,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: CustomPaint(
        key: const ValueKey('heart-rate-violin'),
        painter: _ViolinPainter(
          violins: violins,
          from: lo,
          to: hi,
          textStyle:
              theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ) ??
              const TextStyle(fontSize: 11),
          lineColor: theme.colorScheme.onSurface,
          gridColor: theme.colorScheme.outlineVariant,
          maxColor: theme.colorScheme.error,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

typedef _Violin = ({
  String label,
  List<({int bpm, double density})> shape,
  Quartiles? quartiles,
  Color color,
  int? max,
});

class _ViolinPainter extends CustomPainter {
  _ViolinPainter({
    required this.violins,
    required this.from,
    required this.to,
    required this.textStyle,
    required this.lineColor,
    required this.gridColor,
    required this.maxColor,
  });

  final List<_Violin> violins;
  final int from;
  final int to;
  final TextStyle textStyle;
  final Color lineColor;
  final Color gridColor;
  final Color maxColor;

  static const _left = 36.0;
  static const _bottom = 20.0;

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    bool center = false,
    Color? color,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: color == null ? textStyle : textStyle.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, at - Offset(center ? p.width / 2 : 0, p.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height - _bottom;
    double y(num bpm) => height * (1 - (bpm - from) / (to - from));
    // Grid with four labels.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final bpm = from + (to - from) * i / 3;
      canvas.drawLine(Offset(_left, y(bpm)), Offset(size.width, y(bpm)), grid);
      _text(canvas, '${bpm.round()}', Offset(0, y(bpm)));
    }
    final slot = (size.width - _left) / violins.length;
    for (final (i, v) in violins.indexed) {
      final cx = _left + slot * (i + 0.5);
      final half = slot * 0.38;
      final path = Path();
      for (final (j, p) in v.shape.indexed) {
        final point = Offset(cx + half * p.density, y(p.bpm));
        j == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      for (final p in v.shape.reversed) {
        path.lineTo(cx - half * p.density, y(p.bpm));
      }
      path.close();
      canvas
        ..drawPath(path, Paint()..color = v.color.withValues(alpha: 0.25))
        ..drawPath(
          path,
          Paint()
            ..color = v.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      if (v.quartiles case final q?) {
        final box = Paint()..color = lineColor.withValues(alpha: 0.7);
        canvas
          ..drawRect(Rect.fromLTRB(cx - 4, y(q.q3), cx + 4, y(q.q1)), box)
          ..drawLine(
            Offset(cx - 12, y(q.median)),
            Offset(cx + 12, y(q.median)),
            Paint()
              ..color = lineColor
              ..strokeWidth = 2,
          );
        _text(canvas, '${q.median}', Offset(cx + 16, y(q.median)));
      }
      if (v.max case final max?) {
        canvas.drawLine(
          Offset(cx - half, y(max)),
          Offset(cx + half, y(max)),
          Paint()
            ..color = maxColor
            ..strokeWidth = 2,
        );
        _text(
          canvas,
          S.heartRateViolinMax(max),
          Offset(cx + half + 4, y(max)),
          color: maxColor,
        );
      }
      _text(canvas, v.label, Offset(cx, size.height - 8), center: true);
    }
  }

  @override
  bool shouldRepaint(_ViolinPainter old) =>
      old.violins != violins || old.from != from || old.to != to;
}

/// The highest heart rate of each exercise.
class _PeaksCard extends StatelessWidget {
  const _PeaksCard({required this.peaks});

  final List<(String, int)> peaks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(S.heartRatePerExercise, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final (name, max) in peaks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(name)),
                    Icon(Icons.favorite, size: 16, color: gym.record),
                    const SizedBox(width: 4),
                    Text(
                      '$max ${S.unitBpm}',
                      style: theme.textTheme.titleSmall,
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

/// Minutes in the heart rate zones as one bar and a legend (1.6.0).
class _ZonesCard extends StatelessWidget {
  const _ZonesCard({required this.seconds});

  /// Range 0 (below 1) to 5 → seconds.
  final Map<int, int> seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = seconds.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    return Card.outlined(
      key: const ValueKey('heart-rate-zones'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    S.heartRateZones,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const InfoButton(
                  title: S.heartRateZones,
                  text: S.heartRateZonesInfo,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 16,
                  child: Row(
                    children: [
                      for (var r = 5; r >= 0; r--)
                        if (seconds[r]! > 0)
                          Expanded(
                            flex: seconds[r]!,
                            child: ColoredBox(color: zoneColor(r)),
                          ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (var r = 5; r >= 0; r--)
              if (seconds[r]! > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: zoneColor(r),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r == 0 ? S.heartRateBelowZones : S.hrZone(r),
                        ),
                      ),
                      Text(
                        '${formatTrainingDuration(Duration(seconds: seconds[r]!))}'
                        ' · ${(seconds[r]! * 100 / total).round()} %',
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

/// Heart rate recovery and calories of a training (1.6.0).
class _FiguresCard extends StatelessWidget {
  const _FiguresCard({
    required this.recovery,
    required this.calories,
    required this.caloriesMissing,
  });

  final int? recovery;
  final int? calories;
  final bool caloriesMissing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget figure(
      String label,
      String value,
      String info,
      Key key, {
      bool hint = false,
    }) => Expanded(
      child: Card.outlined(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 0, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  InfoButton(title: label, text: info),
                ],
              ),
              Text(
                value,
                style: hint
                    ? theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        figure(
          S.heartRateRecovery,
          recovery == null ? '–' : S.heartRateRecoveryValue(recovery!),
          S.heartRateRecoveryInfo,
          const ValueKey('heart-rate-recovery'),
        ),
        const SizedBox(width: 8),
        figure(
          S.calories,
          calories == null
              ? (caloriesMissing ? S.caloriesNeedProfile : '–')
              : S.caloriesValue(calories!),
          S.caloriesInfo,
          const ValueKey('heart-rate-calories'),
          hint: calories == null && caloriesMissing,
        ),
      ],
    );
  }
}
