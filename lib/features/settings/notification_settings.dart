import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/models.dart';
import '../../widgets/number_stepper.dart';
import '../../widgets/settings_section.dart';

/// Settings → Benachrichtigungen (1.2.0, own page since 1.2.1).
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text(S.sectionNotifications)),
      body: settings == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                NotificationSettings(
                  settings: settings,
                  update: settingsUpdater(context, ref),
                ),
              ],
            ),
    );
  }
}

class NotificationSettings extends StatelessWidget {
  const NotificationSettings({
    required this.settings,
    required this.update,
    super.key,
  });

  final AppSettings settings;
  final SettingsUpdate update;

  Future<void> _pickEvening(BuildContext context) async {
    final m = settings.eveningMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      await update(
        (s) => s.copyWith(eveningMinute: picked.hour * 60 + picked.minute),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    const step = 15;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsSectionHeader(S.sectionReminders, first: true),
        SwitchListTile(
          title: const Text(S.settingNotifyEvening),
          subtitle: Text(
            S.settingNotifyEveningSubtitle(formatMinuteOfDay(s.eveningMinute)),
          ),
          value: s.notifyEvening,
          onChanged: (v) => update((x) => x.copyWith(notifyEvening: v)),
        ),
        if (s.notifyEvening)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            title: const Text(S.changeTime),
            trailing: TextButton(
              onPressed: () => _pickEvening(context),
              child: Text(formatMinuteOfDay(s.eveningMinute)),
            ),
            onTap: () => _pickEvening(context),
          ),
        SwitchListTile(
          title: const Text(S.settingNotifyBefore),
          subtitle: Text(S.settingNotifyBeforeSubtitle(s.beforeMinutes)),
          value: s.notifyBefore,
          onChanged: (v) => update((x) => x.copyWith(notifyBefore: v)),
        ),
        if (s.notifyBefore)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 16),
            child: NumberStepper(
              plainLabel: true,
              label: S.settingBeforeMinutes,
              valueText: '${s.beforeMinutes} ${S.minutesUnit}',
              onDecrement: s.beforeMinutes > step
                  ? () => update(
                      (x) => x.copyWith(beforeMinutes: x.beforeMinutes - step),
                    )
                  : null,
              onIncrement: s.beforeMinutes < 240
                  ? () => update(
                      (x) => x.copyWith(beforeMinutes: x.beforeMinutes + step),
                    )
                  : null,
            ),
          ),
        SwitchListTile(
          title: const Text(S.settingNotifyStreak),
          subtitle: const Text(S.settingNotifyStreakSubtitle),
          value: s.notifyStreak,
          onChanged: (v) => update((x) => x.copyWith(notifyStreak: v)),
        ),
        SwitchListTile(
          title: const Text(S.settingNotifyBackup),
          subtitle: const Text(S.settingNotifyBackupSubtitle),
          value: s.notifyBackup,
          onChanged: (v) => update((x) => x.copyWith(notifyBackup: v)),
        ),
        const SettingsSectionHeader(S.sectionDuringTraining),
        SwitchListTile(
          title: const Text(S.settingNotifyRest),
          subtitle: const Text(S.settingNotifyRestSubtitle),
          value: s.notifyRest,
          onChanged: (v) => update((x) => x.copyWith(notifyRest: v)),
        ),
        SwitchListTile(
          title: const Text(S.settingNotifyOpenSession),
          subtitle: const Text(S.settingNotifyOpenSessionSubtitle),
          value: s.notifyOpenSession,
          onChanged: (v) => update((x) => x.copyWith(notifyOpenSession: v)),
        ),
        const SettingsSectionHeader(S.sectionUpdates),
        SwitchListTile(
          title: const Text(S.settingCheckUpdates),
          subtitle: const Text(S.settingCheckUpdatesSubtitle),
          value: s.checkUpdates,
          onChanged: (v) => update((x) => x.copyWith(checkUpdates: v)),
        ),
      ],
    );
  }
}

/// The booking page; saved when leaving the field or pressing "done".
class BookingUrlField extends StatefulWidget {
  const BookingUrlField({
    required this.initial,
    required this.onSave,
    super.key,
  });

  final String initial;
  final Future<void> Function(String) onSave;

  @override
  State<BookingUrlField> createState() => _BookingUrlFieldState();
}

class _BookingUrlFieldState extends State<BookingUrlField> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    if (!isValidBookingUrl(url)) {
      setState(() => _error = S.errorBookingUrl);
      return;
    }
    setState(() => _error = null);
    if (url != widget.initial) await widget.onSave(url);
  }

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (focused) {
      if (!focused) _save();
    },
    child: TextField(
      controller: _controller,
      keyboardType: TextInputType.url,
      autocorrect: false,
      maxLines: 2,
      minLines: 1,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
      decoration: InputDecoration(
        labelText: S.settingBookingUrl,
        hintText: S.settingBookingUrlHint,
        errorText: _error,
      ),
    ),
  );
}
