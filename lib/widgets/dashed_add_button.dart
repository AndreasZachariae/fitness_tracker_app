import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Full-width button with a dashed outline, e.g. "+ Übung hinzufügen".
class DashedAddButton extends StatelessWidget {
  const DashedAddButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
    this.color,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  /// Text, icon and outline; default: primary text on the outline color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.primary;
    return CustomPaint(
      painter: _DashedBorderPainter(color: color ?? scheme.outline),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTheme.primaryActionHeight,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: fg),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: fg, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppTheme.buttonRadius),
    ).deflate(0.75);
    const dash = 6.0;
    const gap = 4.0;
    for (final PathMetric metric in (Path()..addRRect(rect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
