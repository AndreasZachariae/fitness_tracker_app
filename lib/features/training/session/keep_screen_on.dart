import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';

/// Keeps the display on while a session runs and `keepScreenOn` is set
/// (SPEC §6.2). Releases it otherwise.
class KeepScreenOn extends ConsumerStatefulWidget {
  const KeepScreenOn({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<KeepScreenOn> createState() => _KeepScreenOnState();
}

class _KeepScreenOnState extends ConsumerState<KeepScreenOn> {
  bool? _applied;
  late final ScreenAwake _screen = ref.read(screenAwakeProvider);

  void _apply(bool on) {
    if (_applied == on) return;
    _applied = on;
    _screen.set(on);
  }

  @override
  void dispose() {
    if (_applied ?? false) _screen.set(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeSessionProvider).value != null;
    final keepOn = (ref.watch(settingsProvider).value ?? AppSettings.defaults)
        .keepScreenOn;
    _apply(active && keepOn);
    return widget.child;
  }
}
