import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Listens to [stream], waits for its first value, runs [actions] and
/// returns all values emitted until then (distinct consecutive values).
Future<List<T>> recordStream<T>(
  Stream<T> stream,
  Future<void> Function() actions,
) async {
  final values = <T>[];
  final first = Completer<void>();
  final sub = stream.listen((v) {
    if (values.isEmpty || values.last.toString() != v.toString()) {
      values.add(v);
    }
    if (!first.isCompleted) first.complete();
  });
  await first.future;
  await actions();
  await pumpEventQueue();
  await sub.cancel();
  return values;
}
