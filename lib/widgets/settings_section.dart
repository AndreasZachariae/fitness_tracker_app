import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../domain/models/models.dart';
import 'snackbars.dart';

/// A clearly visible section header within a settings page (1.2.1): line
/// above, larger text in the primary colour.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.text, {this.first = false, super.key});

  final String text;

  /// No line above the first section of a page.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!first) const Divider(height: 32, indent: 16, endIndent: 16),
        Padding(
          padding: EdgeInsets.fromLTRB(16, first ? 16 : 0, 16, 4),
          child: Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Saves a change of the settings and shows errors.
typedef SettingsUpdate = Future<void> Function(
  AppSettings Function(AppSettings) change,
);

SettingsUpdate settingsUpdater(BuildContext context, WidgetRef ref) =>
    (change) async {
      try {
        await ref.read(settingsRepositoryProvider).update(change);
      } on Object catch (e) {
        if (context.mounted) showError(context, e);
      }
    };
