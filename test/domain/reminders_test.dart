import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/models.dart';
import 'package:gymlog/domain/reminders.dart';

import '../helpers/test_db.dart';

/// testNow: Tue 3.11.2026, 18:20 local (Berlin, UTC+1).
void main() {
  final created = DateTime.utc(2026);
  Plan plan(int id, {bool active = true}) => Plan(
    id: id,
    name: 'Plan $id',
    position: id,
    createdAt: created,
    active: active,
  );
  PlanScheduleEntry day(int planId, int weekday, int hour, [int min = 0]) =>
      PlanScheduleEntry(
        id: weekday,
        planId: planId,
        weekday: weekday,
        minuteOfDay: hour * 60 + min,
      );
  DateTime local(int month, int d, int h, [int m = 0]) =>
      DateTime(2026, month, d, h, m).toUtc();

  List<Reminder> plan1({
    AppSettings settings = AppSettings.defaults,
    bool active = true,
    List<PlanScheduleEntry>? days,
    Session? session,
  }) => plannedReminders(
    now: testNow,
    settings: settings,
    plans: [
      (
        plan(1, active: active),
        days ??
            [day(1, DateTime.monday, 18), day(1, DateTime.thursday, 18, 30)],
      ),
    ],
    activeSession: session,
  );

  group('training days', () {
    test('evening before at 20:00 and 1 h before, two weeks ahead', () {
      final r = plan1();
      final evening = r.where((x) => x.kind == ReminderKind.evening).toList();
      final before = r.where((x) => x.kind == ReminderKind.before).toList();
      expect(evening.first.at, local(11, 4, 20), reason: 'Wed for Thu');
      expect(evening.first.trainingAt, DateTime(2026, 11, 5, 18, 30));
      expect(before.first.at, local(11, 5, 17, 30));
      expect(evening[1].at, local(11, 8, 20), reason: 'Sun for Mon');
      expect(before.map((x) => x.at.isAfter(testNow)), everyElement(isTrue));
      // 3.11. … 17.11.: Thu 5., Mon 9., Thu 12., Mon 16.
      expect(before, hasLength(4));
      expect(evening, hasLength(4));
      expect(r.map((x) => x.id).toSet(), hasLength(r.length), reason: 'ids');
    });

    test('nothing in the past: today 19:00 → only the reminder at 18:00 '
        'would be due, but it is 18:20 already', () {
      final r = plan1(days: [day(1, DateTime.tuesday, 19)]);
      expect(
        r.where((x) => x.trainingAt == DateTime(2026, 11, 3, 19)),
        isEmpty,
      );
    });

    test('inactive plans and switched off reminders give nothing', () {
      expect(plan1(active: false), isEmpty);
      final off = AppSettings.defaults.copyWith(
        notifyEvening: false,
        notifyBefore: false,
      );
      expect(plan1(settings: off), isEmpty);
    });

    test('own times: evening 19:30, 2 h before', () {
      final r = plan1(
        settings: AppSettings.defaults.copyWith(
          eveningMinute: 19 * 60 + 30,
          beforeMinutes: 120,
        ),
      );
      expect(
        r.firstWhere((x) => x.kind == ReminderKind.evening).at,
        local(11, 4, 19, 30),
      );
      expect(
        r.firstWhere((x) => x.kind == ReminderKind.before).at,
        local(11, 5, 16, 30),
      );
    });

    test('no "1 h before" today while a training is running', () {
      final session = Session(
        id: 1,
        planId: 1,
        planNameSnapshot: 'Plan 1',
        startedAt: testNow,
        endedAt: null,
        notes: '',
      );
      final r = plan1(days: [day(1, DateTime.tuesday, 20)], session: session);
      expect(
        r.where((x) => x.kind == ReminderKind.before).first.at,
        local(11, 10, 19),
      );
    });
  });

  group('open training', () {
    final session = Session(
      id: 1,
      planId: null,
      planNameSnapshot: null,
      startedAt: testNow.subtract(const Duration(hours: 2)),
      endedAt: null,
      notes: '',
    );

    test('3 h after the last set, else after the start', () {
      final r = plannedReminders(
        now: testNow,
        settings: AppSettings.defaults,
        plans: const [],
        activeSession: session,
        lastSetAt: testNow.subtract(const Duration(minutes: 30)),
      );
      expect(r.single.kind, ReminderKind.openSession);
      expect(r.single.at, testNow.add(const Duration(minutes: 150)));
      final noSet = plannedReminders(
        now: testNow,
        settings: AppSettings.defaults,
        plans: const [],
        activeSession: session,
      );
      expect(noSet.single.at, testNow.add(const Duration(hours: 1)));
    });

    test('switched off: nothing', () {
      expect(
        plannedReminders(
          now: testNow,
          settings: AppSettings.defaults.copyWith(notifyOpenSession: false),
          plans: const [],
          activeSession: session,
        ),
        isEmpty,
      );
    });
  });

  group('backup', () {
    List<Reminder> backup(DateTime? lastBackupAt, {bool trained = true}) =>
        plannedReminders(
          now: testNow,
          settings: AppSettings.defaults.copyWith(
            lastBackupAt: lastBackupAt,
            notifyStreak: false,
          ),
          plans: const [],
          trainingDays: trained ? [LocalDate(2026, 11, 2)] : const [],
        );

    test('due in the future: on that day at 19:00', () {
      final r = backup(testNow.subtract(const Duration(days: 10))).single;
      expect(r.at, local(11, 23, 19), reason: '24.10. + 30 days');
    });

    test('overdue: next Sunday 19:00; never: this evening', () {
      expect(
        backup(testNow.subtract(const Duration(days: 40))).single.at,
        local(11, 8, 19),
      );
      expect(backup(null).single.at, local(11, 3, 19));
    });

    test('nothing without trainings', () {
      expect(backup(null, trained: false), isEmpty);
    });
  });

  group('streak', () {
    List<Reminder> streak(List<LocalDate> days) => plannedReminders(
      now: testNow,
      settings: AppSettings.defaults.copyWith(notifyBackup: false),
      plans: const [],
      trainingDays: days,
    );

    test('running streak, no training this week: Saturday 18:00', () {
      final r = streak([LocalDate(2026, 10, 20), LocalDate(2026, 10, 28)]);
      expect(r.single.kind, ReminderKind.streak);
      expect(r.single.at, local(11, 7, 18));
      expect(r.single.streakWeeks, 2);
    });

    test('trained this week or no streak: nothing', () {
      expect(
        streak([LocalDate(2026, 10, 28), LocalDate(2026, 11, 2)]),
        isEmpty,
      );
      expect(streak([LocalDate(2026, 10, 13)]), isEmpty);
      expect(streak(const []), isEmpty);
    });
  });

  test('isNewerVersion', () {
    expect(isNewerVersion('v1.3.0', '1.2.0'), isTrue);
    expect(isNewerVersion('v1.2.1', '1.2.0+15'), isTrue);
    expect(isNewerVersion('v1.2.0', '1.2.0'), isFalse);
    expect(isNewerVersion('v1.1.9', '1.2.0'), isFalse);
    expect(isNewerVersion('v2.0.0', '1.10.4'), isTrue);
    expect(isNewerVersion('nightly', '1.2.0'), isFalse);
  });
}
