import 'package:flutter/material.dart';

import '../../core/format/formatters.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/models.dart';
import '../../widgets/number_stepper.dart';

/// Settings → Benachrichtigungen (1.2.0).
class NotificationSettings extends StatelessWidget {
  const NotificationSettings({
    required this.settings,
    required this.update,
    super.key,
  });

  final AppSettings settings;
  final Future<void> Function(AppSettings Function(AppSettings)) update;

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _BookingUrlField(
            initial: s.bookingUrl,
            onSave: (url) => update((x) => x.copyWith(bookingUrl: url)),
          ),
        ),
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
        SwitchListTile(
          title: const Text(S.settingNotifyBackup),
          subtitle: const Text(S.settingNotifyBackupSubtitle),
          value: s.notifyBackup,
          onChanged: (v) => update((x) => x.copyWith(notifyBackup: v)),
        ),
        SwitchListTile(
          title: const Text(S.settingNotifyStreak),
          subtitle: const Text(S.settingNotifyStreakSubtitle),
          value: s.notifyStreak,
          onChanged: (v) => update((x) => x.copyWith(notifyStreak: v)),
        ),
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
class _BookingUrlField extends StatefulWidget {
  const _BookingUrlField({required this.initial, required this.onSave});

  final String initial;
  final Future<void> Function(String) onSave;

  @override
  State<_BookingUrlField> createState() => _BookingUrlFieldState();
}

class _BookingUrlFieldState extends State<_BookingUrlField> {
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
