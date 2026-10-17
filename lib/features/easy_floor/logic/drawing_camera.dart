import 'dart:math' as math;
import 'drawing_point.dart';

const minDrawingScale = 1e-7;
const maxDrawingScale = 2.0;

/// Fits world-space bounds without changing the drawing or its proportions.
(double, DrawingPoint)? fitDrawingCamera(
    List<DrawingPoint> points, double width, double height,
    {double margin = 32}) {
  if (points.isEmpty ||
      !width.isFinite ||
      !height.isFinite ||
      width <= 0 ||
      height <= 0) {
    return null;
  }
  if (!margin.isFinite || margin < 0 || points.any((p) => !p.isFinite)) {
    throw ArgumentError('Invalid drawing bounds.');
  }
  var left = points.first.x, right = left;
  var top = points.first.y, bottom = top;
  for (final p in points) {
    left = math.min(left, p.x);
    right = math.max(right, p.x);
    top = math.min(top, p.y);
    bottom = math.max(bottom, p.y);
  }
  final padding = math.min(margin, math.min(width, height) * .2);
  final scale = math
      .min((width - padding * 2) / math.max(1, right - left),
          (height - padding * 2) / math.max(1, bottom - top))
      .clamp(minDrawingScale, maxDrawingScale);
  return (
    scale,
    DrawingPoint(width / 2 - (left + right) * .5 * scale,
        height / 2 - (top + bottom) * .5 * scale)
  );
}
