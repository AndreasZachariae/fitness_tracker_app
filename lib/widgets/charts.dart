import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/format/formatters.dart';
import '../core/l10n/strings_de.dart';
import '../core/theme/app_theme.dart';
import '../domain/models/local_date.dart';
import '../domain/period.dart';

final _epoch = LocalDate(1970, 1, 1);

/// X value of a day in charts.
double dayX(LocalDate day) => day.differenceInDays(_epoch).toDouble();

LocalDate dayFromX(double x) => _epoch.addDays(x.round());

/// Card with a title (and optional subtitle) around a chart or empty text.
class ChartCard extends StatelessWidget {
  const ChartCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.height = 220,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(height: height, child: child),
          ],
        ),
      ),
    );
  }
}

/// Centered hint inside a chart card.
class ChartEmpty extends StatelessWidget {
  const ChartEmpty(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// SegmentedButton "4 W · 3 M · 1 J · Alles".
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final StatsPeriod value;
  final ValueChanged<StatsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<StatsPeriod>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: StatsPeriod.fourWeeks, label: Text(S.period4w)),
        ButtonSegment(value: StatsPeriod.threeMonths, label: Text(S.period3m)),
        ButtonSegment(value: StatsPeriod.oneYear, label: Text(S.period1y)),
        ButtonSegment(value: StatsPeriod.all, label: Text(S.periodAll)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.single),
    );
  }
}

/// Common axes, grid and border for line/bar charts over days.
FlTitlesData dayTitles(
  BuildContext context, {
  required double minX,
  required double maxX,
  String Function(double)? formatY,
  double reservedLeft = 44,
}) {
  final style = Theme.of(context).textTheme.labelSmall
      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
  final span = (maxX - minX).abs();
  final interval = span <= 0 ? 1.0 : (span / 3).ceilToDouble();
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: reservedLeft,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(
            formatY?.call(value) ?? meta.formattedValue,
            style: style,
          ),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: interval,
        // Only interval labels; the extra min/max labels would overlap.
        minIncluded: false,
        maxIncluded: false,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(
            formatShortDate(dayFromX(value).toLocalDateTime()),
            style: style,
          ),
        ),
      ),
    ),
  );
}

FlGridData chartGrid(BuildContext context) => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) => FlLine(
    color: Theme.of(context).colorScheme.outlineVariant,
    strokeWidth: 1,
  ),
);

/// Tooltip style shared by all charts.
LineTouchTooltipData lineTooltip(
  BuildContext context,
  List<LineTooltipItem?> Function(List<LineBarSpot>) items,
) => LineTouchTooltipData(
  getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
  tooltipBorderRadius: BorderRadius.circular(AppTheme.chipRadius),
  fitInsideHorizontally: true,
  fitInsideVertically: true,
  getTooltipItems: items,
);
