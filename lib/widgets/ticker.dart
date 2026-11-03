import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';

/// Rebuilds every [interval] with the current time from the clock provider.
/// Times shown are always computed from stored timestamps, never counted.
class ClockTicker extends ConsumerStatefulWidget {
  const ClockTicker({
    required this.builder,
    this.interval = const Duration(seconds: 1),
    super.key,
  });

  final Widget Function(BuildContext context, DateTime now) builder;
  final Duration interval;

  @override
  ConsumerState<ClockTicker> createState() => _ClockTickerState();
}

class _ClockTickerState extends ConsumerState<ClockTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, ref.watch(clockProvider).now());
}
