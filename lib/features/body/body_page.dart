import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/format/body_format.dart';
import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/router.dart';
import '../../core/theme/gym_colors.dart';
import '../../core/theme/typography.dart';
import '../../data/providers.dart';
import '../../data/repositories/body_weight_repository.dart';
import '../../domain/body_weight.dart';
import '../../domain/models/models.dart';
import '../../domain/period.dart';
import '../../widgets/charts.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/snackbars.dart';
import '../../widgets/tab_page.dart';
import 'heart_rate_profile_card.dart';

/// Tab "Körper" (SPEC §6.6).
class BodyPage extends ConsumerStatefulWidget {
  const BodyPage({super.key});

  @override
  ConsumerState<BodyPage> createState() => _BodyPageState();
}

class _BodyPageState extends ConsumerState<BodyPage> {
  StatsPeriod _period = StatsPeriod.threeMonths;

  /// What the chart and the key figures show (1.7.0).
  BodyMetric _metric = BodyMetric.weight;

  LocalDate get _today => LocalDate.fromDateTime(ref.read(clockProvider).now());

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(bodyWeightsProvider).value;
    final today = LocalDate.fromDateTime(ref.watch(clockProvider).now());
    final entries = all ?? const <BodyWeightEntry>[];
    final metrics = bodyMetricsWithData(entries);
    final metric = metrics.contains(_metric) ? _metric : BodyMetric.weight;
    final stats = bodyMetricStats(entries, metric, _period, today);
    final inPeriod = [
      for (final p in bodyMetricSeries(entries, metric))
        if (_period.contains(p.date, today)) p,
    ];

    return TabPage(
      title: S.tabBody,
      body: all == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _InputCard(
                  last: entries.isEmpty ? null : entries.first,
                  today: _today,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: PeriodSelector(
                    value: _period,
                    onChanged: (p) => setState(() => _period = p),
                  ),
                ),
                // 1.7.0: switch between the measured values.
                if (metrics.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final m in metrics)
                          ChoiceChip(
                            key: ValueKey('body-metric-${m.name}'),
                            label: Text(S.bodyMetric(m)),
                            selected: m == metric,
                            onSelected: (_) => setState(() => _metric = m),
                          ),
                      ],
                    ),
                  ),
                _BodyChart(
                  metric: metric,
                  data: inPeriod,
                  hasAny: entries.isNotEmpty,
                ),
                if (entries.isNotEmpty) ...[
                  _StatsRow(stats: stats, metric: metric),
                  // 1.6.1: the entries on their own page.
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: ListTile(
                      key: const ValueKey('body-entries'),
                      leading: const Icon(Icons.list_alt),
                      title: Text(S.bodyEntriesCount(entries.length)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.bodyEntries),
                    ),
                  ),
                ],
                // 1.6.0: heart rate profile (1.6.1: zones after the LSHF).
                const HeartRateProfileCard(),
              ],
            ),
    );
  }
}

double? parseBodyWeight(String text) {
  final v = parseDecimal(text);
  if (v == null ||
      v < BodyWeightRepository.minKg ||
      v > BodyWeightRepository.maxKg) {
    return null;
  }
  return (v * 10).round() / 10;
}

/// "Gewicht in kg", date chip, "Speichern" (SPEC §6.6).
class _InputCard extends ConsumerStatefulWidget {
  const _InputCard({required this.last, required this.today});

  /// The newest entry: its weight and scale values are prefilled.
  final BodyWeightEntry? last;
  final LocalDate today;

  @override
  ConsumerState<_InputCard> createState() => _InputCardState();
}

class _InputCardState extends ConsumerState<_InputCard> {
  late final _controller = TextEditingController(
    text: widget.last == null ? '' : formatDecimal1(widget.last!.weightKg),
  );

  /// 1.7.0: values of a smart scale, behind "Weitere Werte".
  late final _more = {
    for (final m in BodyMetric.values)
      if (m != BodyMetric.weight) m: TextEditingController(text: _lastText(m)),
  };
  bool _showMore = false;
  final _moreErrors = <BodyMetric, String>{};

  String _lastText(BodyMetric m) => switch (widget.last) {
    final e? => switch (bodyMetricValue(m, e)) {
      final v? => formatDecimal1(v),
      null => '',
    },
    null => '',
  };

  LocalDate? _date;
  String? _error;
  bool _busy = false;

  LocalDate get _day => _date ?? widget.today;

  @override
  void didUpdateWidget(_InputCard old) {
    super.didUpdateWidget(old);
    if (old.last == null && widget.last != null && _controller.text.isEmpty) {
      _controller.text = formatDecimal1(widget.last!.weightKg);
      for (final MapEntry(key: m, value: c) in _more.entries) {
        if (c.text.isEmpty) c.text = _lastText(m);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final c in _more.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// The scale values, or null when hidden (then the stored ones stay).
  /// Errors go to [_moreErrors].
  BodyComposition? _composition() {
    _moreErrors.clear();
    if (!_showMore) return null;
    double? read(BodyMetric m) {
      final text = _more[m]!.text.trim();
      if (text.isEmpty) return null;
      final v = parseDecimal(text);
      final bone = m == BodyMetric.bone;
      final (min, max) = bone
          ? (BodyWeightRepository.minBoneKg, BodyWeightRepository.maxBoneKg)
          : (BodyWeightRepository.minPct, BodyWeightRepository.maxPct);
      if (v == null || v < min || v > max) {
        _moreErrors[m] = bone ? S.errorBoneKg : S.errorBodyPercent;
        return null;
      }
      return v;
    }

    return (
      musclePct: read(BodyMetric.muscle),
      fatPct: read(BodyMetric.fat),
      waterPct: read(BodyMetric.water),
      boneKg: read(BodyMetric.bone),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.toLocalDateTime(),
      firstDate: DateTime(2000),
      lastDate: widget.today.toLocalDateTime(),
    );
    if (picked != null) {
      setState(() => _date = LocalDate(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    final kg = parseBodyWeight(_controller.text);
    final composition = _composition();
    if (kg == null || _moreErrors.isNotEmpty) {
      return setState(() => _error = kg == null ? S.errorBodyWeight : null);
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final repo = ref.read(bodyWeightRepositoryProvider);
    try {
      if (await repo.findByDate(_day) != null) {
        if (!mounted) return;
        final ok = await showConfirmDialog(
          context,
          title: S.overwriteEntry(formatShortDate(_day.toLocalDateTime())),
          confirmLabel: S.overwrite,
        );
        if (!ok) return;
      }
      await repo.save(_day, kg, composition: composition);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() => _date = null);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _day == widget.today;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: NumberStyles.medium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: S.weightKgLabel,
                      suffixText: S.unitKg,
                      errorText: _error,
                      errorMaxLines: 2,
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      isToday
                          ? S.today
                          : formatWeekdayDate(_day.toLocalDateTime()),
                    ),
                    onPressed: _pickDate,
                  ),
                ),
              ],
            ),
            // 1.7.0: only the weight by default; the rest on demand.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('body-more'),
                icon: Icon(_showMore ? Icons.expand_less : Icons.add),
                label: const Text(S.bodyMoreValues),
                onPressed: () => setState(() => _showMore = !_showMore),
              ),
            ),
            if (_showMore) ...[
              Text(
                S.bodyMoreValuesHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final MapEntry(key: m, value: c) in _more.entries)
                    SizedBox(
                      width: 150,
                      child: TextField(
                        key: ValueKey('body-${m.name}'),
                        controller: c,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: S.bodyMetric(m),
                          suffixText: bodyMetricUnit(m),
                          errorText: _moreErrors[m],
                          errorMaxLines: 2,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text(S.save),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chosen body value over time (1.7.0; before only the weight).
class _BodyChart extends StatelessWidget {
  const _BodyChart({
    required this.metric,
    required this.data,
    required this.hasAny,
  });

  final BodyMetric metric;
  final List<BodyPoint> data;
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    if (data.length < 2) {
      return ChartCard(
        title: S.bodyMetric(metric),
        height: 120,
        child: ChartEmpty(hasAny ? S.bodyChartEmpty : S.bodyFirstHint),
      );
    }
    final points = [for (final p in data) FlSpot(dayX(p.date), p.value)];
    // Only the weight has the 7-day average.
    final average = [
      for (final p in data)
        if (p.average case final a?) FlSpot(dayX(p.date), a),
    ];
    final ys = [...points.map((p) => p.y), ...average.map((p) => p.y)];
    final minY = (ys.reduce((a, b) => a < b ? a : b) - 0.5).floorToDouble();
    final maxY = (ys.reduce((a, b) => a > b ? a : b) + 0.5).ceilToDouble();
    final minX = points.first.x;
    final maxX = points.last.x;

    return ChartCard(
      title: S.bodyMetric(metric),
      subtitle: average.isEmpty
          ? S.measurement
          : '${S.measurement} · ${S.average7}',
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: chartGrid(context),
          borderData: FlBorderData(show: false),
          titlesData: dayTitles(
            context,
            minX: minX,
            maxX: maxX,
            formatY: (v) => v.toStringAsFixed(0),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: lineTooltip(
              context,
              (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    s.barIndex == 0
                        ? '${formatShortDate(dayFromX(s.x).toLocalDateTime())}\n'
                              '${formatBodyValue(metric, s.y)}'
                        : '${S.average7}: ${formatBodyValue(metric, s.y)}',
                    TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: points,
              barWidth: 0,
              color: Colors.transparent,
              dotData: FlDotData(
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 3,
                      color: theme.colorScheme.onSurfaceVariant,
                      strokeWidth: 0,
                    ),
              ),
            ),
            if (average.isNotEmpty)
              LineChartBarData(
                spots: average,
                barWidth: 3,
                isCurved: true,
                preventCurveOverShooting: true,
                color: gym.activeEdge,
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.metric});

  final BodyWeightStats stats;
  final BodyMetric metric;

  @override
  Widget build(BuildContext context) {
    String kg(double? v) => v == null ? '–' : formatBodyValue(metric, v);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Stat(
                label: metric == BodyMetric.weight
                    ? S.bodyCurrent
                    : S.bodyCurrentPlain,
                value: kg(stats.current),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                label: S.bodyChange30,
                value: stats.change30Days == null
                    ? '–'
                    : formatBodyChange(metric, stats.change30Days!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                label: S.bodyMinMax,
                value: stats.min == null
                    ? '–'
                    : '${formatDecimal1(stats.min!)} / '
                          '${formatDecimal1(stats.max!)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: NumberStyles.small.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
