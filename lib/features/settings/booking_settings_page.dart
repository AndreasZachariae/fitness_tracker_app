import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../widgets/settings_section.dart';
import 'notification_settings.dart';

/// Settings → Automatische Buchung (1.2.1): for now the booking page, later
/// the booking details (roadmap 1.3.0).
class BookingSettingsPage extends ConsumerWidget {
  const BookingSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final theme = Theme.of(context);
    final update = settingsUpdater(context, ref);
    return Scaffold(
      appBar: AppBar(title: const Text(S.sectionBooking)),
      body: settings == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BookingUrlField(
                  initial: settings.bookingUrl,
                  onSave: (url) => update((s) => s.copyWith(bookingUrl: url)),
                ),
                const SizedBox(height: 12),
                Text(
                  S.bookingInfo,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}
