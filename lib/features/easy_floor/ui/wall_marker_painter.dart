import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import '../logic/drawing_point.dart';
import '../logic/measurement_markers.dart';

void paintWallMarkers(Canvas canvas, Size size, DrawingPoint a, DrawingPoint b,
    {required Offset origin, required double scale}) {
  final delta = b - a, length = delta.length;
  if (length < 10) return;
  final direction = delta * (1 / length);
  final spacing = DrawingUnit.feet.toMm(2) * scale;
  final minorRadius = math.min(1.8, spacing * .16);
  final majorRadius = math.min(2.8, spacing * .24);
  final projections = [
    for (final p in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height)
    ])
      (DrawingPoint((p.dx - origin.dx) / scale, (p.dy - origin.dy) / scale) - a)
          .dot(direction)
  ];
  final paint = Paint()
    ..color = AppColors.label.withValues(alpha: .55)
    ..style = PaintingStyle.fill;
  for (final marker in wallIntervalMarkers(a, b,
      fromMm: projections.reduce(math.min),
      toMm: projections.reduce(math.max))) {
    final point =
        origin + Offset(marker.point.x * scale, marker.point.y * scale);
    if (point.dx < -4 ||
        point.dy < -4 ||
        point.dx > size.width + 4 ||
        point.dy > size.height + 4) {
      continue;
    }
    canvas.drawCircle(
        point, marker.level == 0 ? minorRadius : majorRadius, paint);
  }
}
