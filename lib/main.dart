import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/format/formatters.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = appLocale;
  await initializeDateFormatting(appLocale);
  LicenseRegistry.addLicense(_fontLicenses);
  runApp(const ProviderScope(child: GymLogApp()));
}

/// Bundled fonts are licensed under the SIL Open Font License 1.1.
Stream<LicenseEntry> _fontLicenses() async* {
  final text = await rootBundle.loadString('assets/fonts/OFL.txt');
  yield LicenseEntryWithLineBreaks(const [
    'Barlow',
    'Barlow Semi Condensed',
  ], text);
}
