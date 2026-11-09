/// Which notifications are due when (1.2.0). Pure logic: the texts come
/// from the UI layer, the scheduling from the notification service.
library;

import 'calendar.dart';
import 'models/models.dart';

enum ReminderKind {
  /// Evening before a training day, with "Slot buchen".
  evening,

  /// Shortly before a training, with a motivational line.
  before,

  /// A training is still open 3 hours after the last set.
  openSession,

  /// The backup reminder is due.
  backup,

  /// The streak ends unless there is a training this week.
  streak,
}

/// A notification to schedule. [at] is UTC; [trainingAt] (local) and
/// [planName] for training reminders.
final class Reminder {
  const Reminder({
    required this.id,
    required this.kind,
    required this.at,
    this.planId,
    this.planName,
    this.trainingAt,
    this.streakWeeks,
  });

  final int id;
  final ReminderKind kind;
  final DateTime at;
  final int? planId;
  final String? planName;
  final DateTime? trainingAt;
  final int? streakWeeks;

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.kind == kind &&
      other.at == at &&
      other.planId == planId &&
      other.planName == planName &&
      other.trainingAt == trainingAt &&
      other.streakWeeks == streakWeeks;

  @override
  int get hashCode =>
      Object.hash(id, kind, at, planId, planName, trainingAt, streakWeeks);

  @override
  String toString() => 'Reminder($kind, $at, $planName)';
}

/// Notification ids. Scheduled reminders use [firstScheduledId] ≤ id <
/// [lastScheduledId]; the service cancels and recreates exactly those.
abstract final class ReminderIds {
  static const firstScheduledId = 100000000;
  static const lastScheduledId = 300000100;
  static const _evening = 100000000;
  static const _before = 200000000;
  static const openSession = 300000001;
  static const backup = 300000002;
  static const streak = 300000003;

  /// Shown at once, not scheduled.
  static const update = 400000001;
  static const rest = 400000002;

  static int evening(LocalDate day, int planId) =>
      _evening + _dayKey(day) * 1000 + planId % 1000;

  static int before(LocalDate day, int planId) =>
      _before + _dayKey(day) * 1000 + planId % 1000;

  static int _dayKey(LocalDate day) =>
      day.differenceInDays(LocalDate(2026, 1, 1)) % 90000;
}

/// After this time without a new set a training counts as still open.
const openSessionAfter = Duration(hours: 3);

/// Days ahead that training reminders are scheduled for; the app
/// reschedules on every start and change.
const reminderDays = 14;

/// Time of the backup and streak reminders (local).
const backupReminderMinute = 19 * 60;
const streakReminderWeekday = DateTime.saturday;
const streakReminderMinute = 18 * 60;

/// All reminders to schedule from [now] (UTC).
///
/// [plans] with their training days; inactive plans are ignored.
/// [activeSession] with [lastSetAt] for the open-training reminder.
/// [trainingDays]: local days of finished trainings (for streak and
/// backup).
List<Reminder> plannedReminders({
  required DateTime now,
  required AppSettings settings,
  required List<(Plan, List<PlanScheduleEntry>)> plans,
  Session? activeSession,
  DateTime? lastSetAt,
  List<LocalDate> trainingDays = const [],
}) {
  final result = <Reminder>[];
  final today = LocalDate.fromDateTime(now);

  // Training days of active plans.
  for (var i = 0; i <= reminderDays; i++) {
    final day = today.addDays(i);
    for (final (plan, days) in plans) {
      if (!plan.active) continue;
      for (final entry in days) {
        if (entry.weekday != day.weekday) continue;
        final trainingAt = _local(day, entry.minuteOfDay);
        if (settings.notifyBefore) {
          final at = trainingAt.subtract(
            Duration(minutes: settings.beforeMinutes),
          );
          // Not while a training is already running today.
          final running = activeSession != null && i == 0;
          if (at.isAfter(now) && !running) {
            result.add(
              Reminder(
                id: ReminderIds.before(day, plan.id),
                kind: ReminderKind.before,
                at: at.toUtc(),
                planId: plan.id,
                planName: plan.name,
                trainingAt: trainingAt,
              ),
            );
          }
        }
        if (settings.notifyEvening) {
          final at = _local(day.addDays(-1), settings.eveningMinute);
          if (at.isAfter(now)) {
            result.add(
              Reminder(
                id: ReminderIds.evening(day, plan.id),
                kind: ReminderKind.evening,
                at: at.toUtc(),
                planId: plan.id,
                planName: plan.name,
                trainingAt: trainingAt,
              ),
            );
          }
        }
      }
    }
  }

  // Training still open.
  if (settings.notifyOpenSession && activeSession != null) {
    final from = lastSetAt ?? activeSession.startedAt;
    final at = from.add(openSessionAfter);
    if (at.isAfter(now)) {
      result.add(
        Reminder(
          id: ReminderIds.openSession,
          kind: ReminderKind.openSession,
          at: at.toUtc(),
        ),
      );
    }
  }

  // Backup due.
  if (settings.notifyBackup &&
      settings.backupReminderDays > 0 &&
      trainingDays.isNotEmpty) {
    final last = settings.lastBackupAt;
    final dueDay = last == null
        ? today
        : LocalDate.fromDateTime(
            last.add(Duration(days: settings.backupReminderDays)),
          );
    var at = _local(dueDay, backupReminderMinute);
    // Already overdue: once a week, on Sunday evening.
    if (!at.isAfter(now)) {
      var day = today;
      while (day.weekday != DateTime.sunday ||
          !_local(day, backupReminderMinute).isAfter(now)) {
        day = day.addDays(1);
      }
      at = _local(day, backupReminderMinute);
    }
    result.add(
      Reminder(
        id: ReminderIds.backup,
        kind: ReminderKind.backup,
        at: at.toUtc(),
      ),
    );
  }

  // Streak ends this week.
  if (settings.notifyStreak) {
    final weeks = {for (final d in trainingDays) mondayOf(d)};
    final monday = mondayOf(today);
    final streak = _streak(weeks, monday);
    if (streak > 0 && !weeks.contains(monday)) {
      final at = _local(
        monday.addDays(streakReminderWeekday - 1),
        streakReminderMinute,
      );
      if (at.isAfter(now)) {
        result.add(
          Reminder(
            id: ReminderIds.streak,
            kind: ReminderKind.streak,
            at: at.toUtc(),
            streakWeeks: streak,
          ),
        );
      }
    }
  }
  return result;
}

/// Weeks in a row with training before [monday] (the running week does
/// not count yet).
int _streak(Set<LocalDate> weeks, LocalDate monday) {
  var n = 0;
  var w = monday.addDays(-7);
  while (weeks.contains(w)) {
    n++;
    w = w.addDays(-7);
  }
  return n;
}

DateTime _local(LocalDate day, int minuteOfDay) =>
    DateTime(day.year, day.month, day.day, minuteOfDay ~/ 60, minuteOfDay % 60);
