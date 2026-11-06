import 'package:gymlog/core/device.dart';

/// Records calls instead of vibrating.
final class FakeFeedback implements DeviceFeedback {
  final calls = <String>[];

  @override
  Future<void> setSaved() async => calls.add('setSaved');

  @override
  Future<void> record() async => calls.add('record');

  @override
  Future<void> restOver() async => calls.add('restOver');
}

/// Records scheduled and cancelled rest alarms.
final class FakeRestAlarm implements RestAlarm {
  final calls = <String>[];
  DateTime? scheduledAt;

  @override
  Future<void> schedule(DateTime at) async {
    scheduledAt = at;
    calls.add('schedule');
  }

  @override
  Future<void> cancel() async {
    scheduledAt = null;
    calls.add('cancel');
  }
}

final class FakeScreenAwake implements ScreenAwake {
  final states = <bool>[];

  bool get on => states.isNotEmpty && states.last;

  @override
  Future<void> set(bool on) async => states.add(on);
}
