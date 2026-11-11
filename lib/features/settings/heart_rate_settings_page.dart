import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/heart_rate_monitor.dart';
import '../../core/l10n/strings_de.dart';
import '../../data/providers.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/snackbars.dart';

/// Settings → Pulsmesser (1.5.0): find a Bluetooth heart rate monitor (a
/// chest strap or a watch that broadcasts), keep it, try it out.
class HeartRateSettingsPage extends ConsumerStatefulWidget {
  const HeartRateSettingsPage({super.key});

  @override
  ConsumerState<HeartRateSettingsPage> createState() =>
      _HeartRateSettingsPageState();
}

class _HeartRateSettingsPageState extends ConsumerState<HeartRateSettingsPage> {
  StreamSubscription<HeartRateDevice>? _scan;
  final _found = <String, HeartRateDevice>{};

  StreamSubscription<int>? _test;
  int? _testBpm;
  bool _testLost = false;

  @override
  void dispose() {
    unawaited(_scan?.cancel());
    unawaited(_test?.cancel());
    super.dispose();
  }

  /// Bluetooth on and allowed; otherwise explains why not.
  Future<bool> _ready() async {
    final monitor = ref.read(heartRateMonitorProvider);
    var availability = await monitor.availability();
    if (availability == HeartRateAvailability.noPermission &&
        await monitor.requestPermission()) {
      availability = await monitor.availability();
    }
    if (!mounted) return false;
    final problem = switch (availability) {
      HeartRateAvailability.ready => null,
      HeartRateAvailability.unsupported => S.heartRateUnsupported,
      HeartRateAvailability.bluetoothOff => S.heartRateBluetoothOff,
      HeartRateAvailability.noPermission => S.heartRatePermission,
    };
    if (problem != null) showMessage(context, problem);
    return problem == null;
  }

  Future<void> _toggleScan() async {
    if (_scan != null) {
      await _stopScan();
      return;
    }
    await _stopTest();
    if (!await _ready() || !mounted) return;
    setState(() {
      _found.clear();
      _scan = ref
          .read(heartRateMonitorProvider)
          .scan()
          .listen(
            (d) => setState(() => _found[d.id] = d),
            onError: (Object e) {
              if (mounted) showError(context, e);
              unawaited(_stopScan());
            },
          );
    });
  }

  Future<void> _stopScan() async {
    final scan = _scan;
    if (mounted) setState(() => _scan = null);
    await scan?.cancel();
  }

  Future<void> _choose(HeartRateDevice device) async {
    await _stopScan();
    if (!mounted) return;
    await settingsUpdater(context, ref)(
      (s) => s.copyWith(hrDeviceId: device.id, hrDeviceName: device.name),
    );
    if (mounted) showMessage(context, S.heartRateSaved(device.name));
  }

  Future<void> _remove() async {
    await _stopTest();
    if (!mounted) return;
    await settingsUpdater(context, ref)(
      (s) => s.copyWith(hrDeviceId: null, hrDeviceName: null),
    );
  }

  Future<void> _toggleTest(String deviceId) async {
    if (_test != null) {
      await _stopTest();
      return;
    }
    await _stopScan();
    if (!await _ready() || !mounted) return;
    setState(() {
      _testBpm = null;
      _testLost = false;
      _test = ref
          .read(heartRateMonitorProvider)
          .heartRate(deviceId)
          .listen(
            (bpm) => setState(() {
              _testBpm = bpm;
              _testLost = false;
            }),
            onError: (Object _) => setState(() => _testLost = true),
            onDone: () => setState(() => _testLost = true),
          );
    });
  }

  Future<void> _stopTest() async {
    final test = _test;
    if (mounted) setState(() => _test = null);
    await test?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).value;
    final training = ref.watch(activeSessionProvider).value != null;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final deviceId = settings?.hrDeviceId;
    final testing = _test != null;
    final testText = _testLost
        ? S.heartRateLost
        : _testBpm == null
        ? S.heartRateConnecting
        : S.heartRateNow(_testBpm!);

    return Scaffold(
      appBar: AppBar(title: const Text(S.sectionHeartRate)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(S.heartRateIntro, style: theme.textTheme.bodyMedium),
          ),
          if (deviceId != null) ...[
            const SettingsSectionHeader(S.heartRateDevice),
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: Text(settings?.hrDeviceName ?? deviceId),
              subtitle: Text(
                training
                    ? S.heartRateDuringTraining
                    : testing
                    ? testText
                    : deviceId,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  if (!training)
                    OutlinedButton.icon(
                      icon: Icon(testing ? Icons.stop : Icons.favorite_border),
                      label: Text(
                        testing ? S.heartRateStopTest : S.heartRateTest,
                      ),
                      onPressed: () => _toggleTest(deviceId),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text(S.heartRateRemove),
                    onPressed: _remove,
                  ),
                ],
              ),
            ),
          ],
          const SettingsSectionHeader(S.heartRateSearch),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                icon: Icon(
                  _scan != null ? Icons.stop : Icons.bluetooth_searching,
                ),
                label: Text(
                  _scan != null ? S.heartRateStopSearch : S.heartRateSearch,
                ),
                // A running training holds the connection.
                onPressed: training ? null : _toggleScan,
              ),
            ),
          ),
          if (_scan != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(S.heartRateSearching, style: muted)),
                ],
              ),
            ),
            if (_found.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(S.heartRateChooseHint, style: muted),
              ),
            for (final d in _found.values)
              ListTile(
                leading: const Icon(Icons.watch_outlined),
                title: Text(d.name),
                subtitle: d.name == d.id ? null : Text(d.id),
                trailing: d.id == deviceId ? const Icon(Icons.check) : null,
                onTap: () => _choose(d),
              ),
          ],
          // How to make a Garmin watch broadcast; at the end, the buttons
          // first.
          const SettingsSectionHeader(S.heartRateHowTo),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(S.heartRateGarminHint, style: muted),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(S.heartRateWristHint, style: muted),
          ),
        ],
      ),
    );
  }
}
