import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/theme/gym_colors.dart';
import '../../core/theme/typography.dart';
import '../../data/providers.dart';
import '../../data/repositories/body_weight_repository.dart';
import '../../domain/body_weight.dart';
import '../../domain/models/models.dart';
import '../../domain/period.dart';
import '../../widgets/charts.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/number_input_dialog.dart';
import '../../widgets/snackbars.dart';
import '../../widgets/tab_page.dart';

/// Tab "Körper" (SPEC §6.6).
class BodyPage extends ConsumerStatefulWidget {
  const BodyPage({super.key});

  @override
  ConsumerState<BodyPage> createState() => _BodyPageState();
}

class _BodyPageState extends ConsumerState<BodyPage> {
  StatsPeriod _period = StatsPeriod.threeMonths;

  /// Deleted entries hidden at once until the stream catches up.
  final _hidden = <int>{};

  LocalDate get _today => LocalDate.fromDateTime(ref.read(clockProvider).now());

  Future<void> _delete(BodyWeightEntry entry) async {
    setState(() => _hidden.add(entry.id));
    final repo = ref.read(bodyWeightRepositoryProvider);
    try {
      await repo.delete(entry.id);
      if (!mounted) return;
      showMessage(
        context,
        S.entryDeleted(formatShortDate(entry.date.toLocalDateTime())),
        onUndo: () => repo.restore(entry).catchError((Object e) {
          if (mounted) showError(context, e);
        }),
      );
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _hidden.remove(entry.id));
    }
  }

  Future<void> _edit(BodyWeightEntry entry) async {
    final kg = await showNumberInputDialog<double>(
      context,
      title:
          '${S.editEntry} · ${formatShortDate(entry.date.toLocalDateTime())}',
      initialText: formatDecimal1(entry.weightKg),
      decimal: true,
      parse: _parseBodyWeight,
    );
    if (kg == null) return;
    try {
      await ref.read(bodyWeightRepositoryProvider).save(entry.date, kg);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(bodyWeightsProvider).value;
    final today = LocalDate.fromDateTime(ref.watch(clockProvider).now());
    final entries = [
      for (final e in all ?? const <BodyWeightEntry>[])
        if (!_hidden.contains(e.id)) e,
    ];
    final smoothed = movingAverage7(entries);
    final stats = bodyWeightStats(smoothed, _period, today);
    final inPeriod = [
      for (final s in smoothed)
        if (_period.contains(s.entry.date, today)) s,
    ];

    return TabPage(
      title: S.tabBody,
      body: all == null
          ? const SizedBox.shrink()
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: entries.length + 4,
              itemBuilder: (context, i) => switch (i) {
                0 => _InputCard(
                  lastWeight: entries.isEmpty ? null : entries.first.weightKg,
                  today: _today,
                ),
                1 => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: PeriodSelector(
                    value: _period,
                    onChanged: (p) => setState(() => _period = p),
                  ),
                ),
                2 => Column(
                  children: [
                    _WeightChart(data: inPeriod, hasAny: entries.isNotEmpty),
                    if (entries.isNotEmpty) _StatsRow(stats: stats),
                  ],
                ),
                3 =>
                  entries.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            S.bodyEntries,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                _ => _EntryTile(
                  entry: entries[i - 4],
                  onDelete: _delete,
                  onTap: _edit,
                ),
              },
            ),
    );
  }
}

double? _parseBodyWeight(String text) {
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
  const _InputCard({required this.lastWeight, required this.today});

  final double? lastWeight;
  final LocalDate today;

  @override
  ConsumerState<_InputCard> createState() => _InputCardState();
}

class _InputCardState extends ConsumerState<_InputCard> {
  late final _controller = TextEditingController(
    text: widget.lastWeight == null ? '' : formatDecimal1(widget.lastWeight!),
  );
  LocalDate? _date;
  String? _error;
  bool _busy = false;

  LocalDate get _day => _date ?? widget.today;

  @override
  void didUpdateWidget(_InputCard old) {
    super.didUpdateWidget(old);
    if (old.lastWeight == null &&
        widget.lastWeight != null &&
        _controller.text.isEmpty) {
      _controller.text = formatDecimal1(widget.lastWeight!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    final kg = _parseBodyWeight(_controller.text);
    if (kg == null) return setState(() => _error = S.errorBodyWeight);
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
      await repo.save(_day, kg);
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

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.data, required this.hasAny});

  final List<SmoothedWeight> data;
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    if (data.length < 2) {
      return ChartCard(
        title: S.weight,
        height: 120,
        child: ChartEmpty(hasAny ? S.bodyChartEmpty : S.bodyFirstHint),
      );
    }
    final points = [
      for (final s in data) FlSpot(dayX(s.entry.date), s.entry.weightKg),
    ];
    final average = [
      for (final s in data) FlSpot(dayX(s.entry.date), s.average),
    ];
    final ys = [...points.map((p) => p.y), ...average.map((p) => p.y)];
    final minY = (ys.reduce((a, b) => a < b ? a : b) - 0.5).floorToDouble();
    final maxY = (ys.reduce((a, b) => a > b ? a : b) + 0.5).ceilToDouble();
    final minX = points.first.x;
    final maxX = points.last.x;

    return ChartCard(
      title: S.weight,
      subtitle: '${S.measurement} · ${S.average7}',
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
                              '${formatKg1(s.y)}'
                        : '${S.average7}: ${formatKg1(s.y)}',
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
  const _StatsRow({required this.stats});

  final BodyWeightStats stats;

  @override
  Widget build(BuildContext context) {
    String kg(double? v) => v == null ? '–' : formatKg1(v);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Stat(label: S.bodyCurrent, value: kg(stats.current)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                label: S.bodyChange30,
                value: stats.change30Days == null
                    ? '–'
                    : formatSignedKg1(stats.change30Days!),
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

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onDelete,
    required this.onTap,
  });

  final BodyWeightEntry entry;
  final ValueChanged<BodyWeightEntry> onDelete;
  final ValueChanged<BodyWeightEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => onDelete(entry),
      child: ListTile(
        title: Text(
          formatKg1(entry.weightKg),
          style: NumberStyles.small.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(formatWeekdayDate(entry.date.toLocalDateTime())),
        trailing: const Icon(Icons.edit_outlined, size: 20),
        onTap: () => onTap(entry),
      ),
    );
  }
}
