import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../../widgets/snackbars.dart';

/// Default time of a newly ticked training day.
const defaultTrainingMinute = 18 * 60;

/// "Trainingstage und Uhrzeit" of a plan (1.2.0): active switch and per
/// weekday a tick with its time. Every change is saved at once.
Future<void> showPlanScheduleSheet(BuildContext context, Plan plan) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PlanScheduleSheet(planId: plan.id),
    );

/// Short form for lists: `Mo, Do 18:00` / `Mo 18:00, Do 18:30`.
String formatPlanSchedule(List<PlanScheduleEntry> days) {
  if (days.isEmpty) return S.noTrainingDays;
  final sorted = [...days]..sort((a, b) => a.weekday.compareTo(b.weekday));
  final times = sorted.map((d) => d.minuteOfDay).toSet();
  String day(PlanScheduleEntry d) => S.weekdayInitials[d.weekday - 1];
  if (times.length == 1) {
    return '${sorted.map(day).join(', ')} ${formatMinuteOfDay(times.single)}';
  }
  return sorted
      .map((d) => '${day(d)} ${formatMinuteOfDay(d.minuteOfDay)}')
      .join(', ');
}

class _PlanScheduleSheet extends ConsumerWidget {
  const _PlanScheduleSheet({required this.planId});

  final int planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan = ref
        .watch(plansProvider)
        .value
        ?.where((p) => p.id == planId)
        .firstOrNull;
    final days = <int, int>{
      for (final e
          in ref.watch(planSchedulesProvider).value ??
              const <PlanScheduleEntry>[])
        if (e.planId == planId) e.weekday: e.minuteOfDay,
    };
    if (plan == null) return const SizedBox.shrink();
    final repo = ref.read(planRepositoryProvider);

    Future<void> save(Future<void> Function() action) async {
      try {
        await action();
      } on Object catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    Future<void> pickTime(int weekday) async {
      final current = days[weekday] ?? defaultTrainingMinute;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (picked == null) return;
      await save(
        () => repo.setSchedule(planId, {
          ...days,
          weekday: picked.hour * 60 + picked.minute,
        }),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              '${S.planScheduleTitle}: ${plan.name}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          SwitchListTile(
            title: const Text(S.planActive),
            subtitle: const Text(S.planActiveSubtitle),
            value: plan.active,
            onChanged: (v) => save(() => repo.setActive(planId, v)),
          ),
          const Divider(),
          for (var weekday = 1; weekday <= 7; weekday++)
            CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(S.weekdays[weekday - 1]),
              value: days.containsKey(weekday),
              onChanged: (v) => save(
                () => repo.setSchedule(planId, {
                  for (final e in days.entries)
                    if (e.key != weekday) e.key: e.value,
                  if (v ?? false)
                    weekday: days.values.isEmpty
                        ? defaultTrainingMinute
                        : days.values.last,
                }),
              ),
              secondary: days.containsKey(weekday)
                  ? TextButton(
                      onPressed: () => pickTime(weekday),
                      child: Text(
                        formatMinuteOfDay(days[weekday]!),
                        semanticsLabel:
                            '${S.changeTime}: ${S.weekdays[weekday - 1]}',
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
