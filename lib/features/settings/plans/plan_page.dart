import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings_de.dart';
import '../../../core/router.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../../widgets/settings_section.dart';
import '../../../widgets/snackbars.dart';
import 'plan_actions.dart';

/// Default time of a newly ticked training day.
const defaultTrainingMinute = 18 * 60;

/// Opens the page of a plan (1.2.1): from Settings → Pläne and by a long
/// press on a plan chip in the training tab.
Future<void> openPlanPage(BuildContext context, int planId) =>
    context.push(AppRoutes.plan(planId));

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

/// Everything about one plan (1.2.1): name, active, training days,
/// duplicate, delete. Every change is saved at once.
class PlanPage extends ConsumerWidget {
  const PlanPage({required this.planId, super.key});

  final int planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plans = ref.watch(plansProvider).value;
    final plan = plans?.where((p) => p.id == planId).firstOrNull;
    if (plan == null) {
      // Loading, or just deleted.
      return Scaffold(appBar: AppBar());
    }
    final repo = ref.read(planRepositoryProvider);

    Future<void> save(Future<void> Function() action) async {
      try {
        await action();
      } on Object catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(plan.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text(S.planNameLabel),
            subtitle: Text(plan.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => renamePlanWithDialog(context, ref, plan),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.play_circle_outline),
            title: const Text(S.planActive),
            subtitle: const Text(S.planActiveSubtitle),
            value: plan.active,
            onChanged: (v) => save(() => repo.setActive(planId, v)),
          ),
          const SettingsSectionHeader(S.planSchedule),
          TrainingDaysEditor(planId: planId, onSave: save),
          const SettingsSectionHeader(S.planMore),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text(S.duplicate),
            onTap: () async {
              final id = await duplicatePlanWithDialog(context, ref, plan);
              if (id != null && context.mounted) {
                context.pushReplacement(AppRoutes.plan(id));
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              S.delete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () async {
              if (await deletePlanWithConfirmation(context, ref, plan) &&
                  context.mounted) {
                context.pop();
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Per weekday a tick with its time (1.2.0); newly ticked days take the
/// last chosen time, else 18:00.
class TrainingDaysEditor extends ConsumerWidget {
  const TrainingDaysEditor({
    required this.planId,
    required this.onSave,
    super.key,
  });

  final int planId;
  final Future<void> Function(Future<void> Function()) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = <int, int>{
      for (final e
          in ref.watch(planSchedulesProvider).value ??
              const <PlanScheduleEntry>[])
        if (e.planId == planId) e.weekday: e.minuteOfDay,
    };
    final repo = ref.read(planRepositoryProvider);

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
      await onSave(
        () => repo.setSchedule(planId, {
          ...days,
          weekday: picked.hour * 60 + picked.minute,
        }),
      );
    }

    return Column(
      children: [
        for (var weekday = 1; weekday <= 7; weekday++)
          CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(S.weekdays[weekday - 1]),
            value: days.containsKey(weekday),
            onChanged: (v) => onSave(
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
    );
  }
}
