import '../../core/clock.dart';
import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../core/notifications.dart';
import '../../domain/models/models.dart';
import '../../domain/reminders.dart';
import '../repositories/plan_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/settings_repository.dart';

/// Payloads and button ids of GymLog notifications (1.2.0).
abstract final class NotificationPayloads {
  static const plan = 'plan';
  static const session = 'session';
  static const backup = 'backup';
  static const streak = 'streak';
  static const update = 'update';

  /// Button "Slot buchen": opens the booking page.
  static const bookButton = 'book';
}

/// Plans the reminders of the next days as notifications (1.2.0). [sync]
/// cancels all planned ones and plans them again from the current data;
/// it runs at app start and after every relevant change.
class ReminderService {
  ReminderService({
    required this.gateway,
    required this.plans,
    required this.sessions,
    required this.settings,
    required this.clock,
  });

  final NotificationGateway gateway;
  final PlanRepository plans;
  final SessionRepository sessions;
  final SettingsRepository settings;
  final Clock clock;

  Future<void> sync() async {
    final s = await settings.get();
    final allPlans = await plans.getPlans();
    final schedules = await plans.getAllSchedules();
    final active = await sessions.getActive();
    final lastSet = active == null
        ? null
        : await sessions.lastSetTime(active.id);
    final finished = await sessions.getFinished();
    final reminders = plannedReminders(
      now: clock.now(),
      settings: s,
      plans: [
        for (final p in allPlans)
          (
            p,
            [
              for (final e in schedules)
                if (e.planId == p.id) e,
            ],
          ),
      ],
      activeSession: active,
      lastSetAt: lastSet,
      trainingDays: [
        for (final f in finished) LocalDate.fromDateTime(f.startedAt),
      ],
    );

    for (final id in await gateway.scheduledIds()) {
      if (id >= ReminderIds.firstScheduledId &&
          id < ReminderIds.lastScheduledId) {
        await gateway.cancel(id);
      }
    }
    for (final r in reminders) {
      final (title, body, payload) = _text(r, s);
      await gateway.schedule(
        id: r.id,
        at: r.at,
        title: title,
        body: body,
        payload: payload,
        buttons: r.kind == ReminderKind.evening
            ? const [(id: NotificationPayloads.bookButton, label: S.bookSlot)]
            : const [],
      );
    }
  }

  static (String, String, String) _text(Reminder r, AppSettings s) =>
      switch (r.kind) {
        ReminderKind.evening => (
          S.notifyEveningTitle(r.planName!, formatClockTime(r.trainingAt!)),
          S.notifyEveningBody,
          NotificationPayloads.plan,
        ),
        ReminderKind.before => (
          S.notifyBeforeTitle(s.beforeMinutes, r.planName!),
          S.motivation[r.id % S.motivation.length],
          NotificationPayloads.plan,
        ),
        ReminderKind.openSession => (
          S.notifyOpenSessionTitle,
          S.notifyOpenSessionBody,
          NotificationPayloads.session,
        ),
        ReminderKind.backup => (
          S.notifyBackupTitle,
          S.notifyBackupBody,
          NotificationPayloads.backup,
        ),
        ReminderKind.streak => (
          S.notifyStreakTitle,
          S.notifyStreakBody(r.streakWeeks ?? 1),
          NotificationPayloads.streak,
        ),
      };
}
