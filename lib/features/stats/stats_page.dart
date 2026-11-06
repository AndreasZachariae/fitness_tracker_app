import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../domain/models/models.dart';
import '../../domain/period.dart';
import '../../domain/statistics.dart';
import '../../widgets/charts.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tab_page.dart';
import 'exercise_stats_tab.dart';
import 'overall_stats_tab.dart';
import 'records_tab.dart';

/// Tab "Statistik" (SPEC §6.5).
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this);
  StatsPeriod _period = StatsPeriod.threeMonths;
  int? _exerciseId;
  final _metrics = <int, ExerciseMetric>{};

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openExercise(int exerciseId) {
    setState(() => _exerciseId = exerciseId);
    _tabs.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(statsDataProvider).value;
    final today = LocalDate.fromDateTime(ref.watch(clockProvider).now());
    return TabPage(
      title: S.tabStats,
      body: data == null
          ? const SizedBox.shrink()
          : data.trainings.isEmpty
          ? const EmptyState(icon: Icons.insights, message: S.statsNoData)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: PeriodSelector(
                      value: _period,
                      onChanged: (p) => setState(() => _period = p),
                    ),
                  ),
                ),
                // Three short tabs; beyond 150 % they would be cut (M10).
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.5,
                  child: TabBar(
                    controller: _tabs,
                    tabs: const [
                      Tab(text: S.statsTabExercise),
                      Tab(text: S.statsTabOverall),
                      Tab(text: S.statsTabRecords),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      ExerciseStatsTab(
                        data: data,
                        period: _period,
                        today: today,
                        exerciseId: _exerciseId,
                        metrics: _metrics,
                        onExercise: (id) => setState(() => _exerciseId = id),
                        onMetric: (id, m) => setState(() => _metrics[id] = m),
                      ),
                      OverallStatsTab(
                        data: data,
                        period: _period,
                        today: today,
                      ),
                      RecordsTab(data: data, onTap: _openExercise),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
