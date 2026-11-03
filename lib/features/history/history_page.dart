import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/router.dart';
import '../../core/theme/gym_colors.dart';
import '../../data/providers.dart';
import '../../domain/history.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tab_page.dart';

/// Tab "Verlauf" (SPEC §6.4): finished sessions grouped by month.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider).value;
    return TabPage(
      title: S.tabHistory,
      body: switch (history) {
        null => const SizedBox.shrink(),
        [] => const EmptyState(icon: Icons.history, message: S.historyEmpty),
        final list => _HistoryList(items: list),
      },
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.items});

  final List<SessionSummary> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = groupByMonth(items, (s) => s.session.startedAt);
    final rows = <Widget>[];
    for (final (month, entries) in groups) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(
            formatMonth(month),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
      rows.addAll(entries.map((e) => _HistoryTile(summary: e)));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: rows);
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gym = GymColors.of(context);
    final s = summary.session;
    final number = NumberFormat.decimalPattern(appLocale);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.historyDetail(s.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatWeekdayDate(s.startedAt)} · '
                      '${s.planNameSnapshot ?? S.freeTrainingTitle}',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      S.historyEntry(
                        formatTrainingDuration(summary.duration),
                        summary.setCount,
                        '${number.format(summary.volume.round())} ${S.unitKg}',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (summary.hasRecords)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.emoji_events,
                    color: gym.record,
                    semanticLabel: S.recordsInSession,
                  ),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
