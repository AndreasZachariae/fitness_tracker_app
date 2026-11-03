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

final class FakeScreenAwake implements ScreenAwake {
  final states = <bool>[];

  bool get on => states.isNotEmpty && states.last;

  @override
  Future<void> set(bool on) async => states.add(on);
}
