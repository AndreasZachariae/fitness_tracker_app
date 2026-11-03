import 'dart:async';

import 'package:drift/drift.dart';

/// Global test setup (picked up by `flutter test` automatically).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Tests open many independent in-memory databases on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
