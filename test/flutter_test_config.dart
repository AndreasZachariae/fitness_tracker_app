import 'dart:async';

import 'package:drift/drift.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Global test setup (picked up by `flutter test` automatically).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Tests open many independent in-memory databases on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // Same locale setup as main().
  Intl.defaultLocale = 'de_DE';
  await initializeDateFormatting('de_DE');
  await testMain();
}
