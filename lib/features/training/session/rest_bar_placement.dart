import 'package:flutter/widgets.dart';

/// The one rest bar of the app (1.7.0): it keeps its state (the alarm handed
/// to Android) when it moves between the bottom of the app and the top of
/// the training in the view for a device mount.
final restTimerBarKey = GlobalKey(debugLabel: 'rest-timer-bar');

/// Set by the home shell: whether the training shows the rest bar at the
/// top (mount view, training tab, a training running). Shell and training
/// read the same value in the same frame, so the bar is never in two
/// places.
class RestBarAtTop extends InheritedWidget {
  const RestBarAtTop({required this.top, required super.child, super.key});

  final bool top;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RestBarAtTop>()?.top ?? false;

  @override
  bool updateShouldNotify(RestBarAtTop old) => old.top != top;
}
