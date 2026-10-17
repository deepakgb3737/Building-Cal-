import 'dart:math' as math;
import 'drawing_point.dart';
import 'wall_network.dart';

/// Optional assistance; distances are mm and tolerance comes from screen zoom.
DrawingPoint precisionPoint(WallNetwork model, DrawingPoint point,
    {DrawingPoint? anchor,
    DrawingPoint? previous,
    bool grid = false,
    double gridStep = 100,
    bool axes = false,
    double? angleStep,
    bool parallel = false,
    bool perpendicular = false,
    double angleToleranceDegrees = 3,
    double tolerance = 60,
    Set<int> excludeWalls = const {}}) {
  if (!angleToleranceDegrees.isFinite ||
      angleToleranceDegrees < 0 ||
      angleToleranceDegrees > 45) {
    throw ArgumentError.value(angleToleranceDegrees, 'angleToleranceDegrees',
        'Use an angle from 0 to 45 degrees.');
  }
  final angularTolerance = angleToleranceDegrees * math.pi / 180;
  var result = point;
  if (grid && gridStep.isFinite && gridStep > 0) {
    final target = DrawingPoint((point.x / gridStep).round() * gridStep,
        (point.y / gridStep).round() * gridStep);
    if ((target - point).length <= tolerance) result = target;
  }
  if (anchor == null) return result;
  final d = point - anchor;
  if (d.length < 10) return result;
  final candidates = <DrawingPoint>[];
  void angle(double step) {
    if (!step.isFinite || step <= 0) return;
    final radians = step * math.pi / 180;
    final theta = math.atan2(d.y, d.x),
        nearest = (theta / radians).round() * radians;
    if ((nearest - theta).abs() > angularTolerance + 1e-10) return;
    if ((nearest - theta).abs() < 1e-12) {
      candidates.add(point);
      return;
    }
    candidates.add(
        anchor + DrawingPoint(math.cos(nearest), math.sin(nearest)) * d.length);
  }

  if (axes) angle(90);
  if (angleStep != null) angle(angleStep);
  void along(DrawingPoint direction) {
    if (direction.length < .001) return;
    final target =
        anchor + direction * (d.dot(direction) / direction.dot(direction));
    if ((target - point).length / d.length <=
        math.sin(angularTolerance) + 1e-10) {
      candidates.add(target);
    }
  }

  if (axes && previous != null) {
    final axis = anchor - previous;
    along(axis);
    along(DrawingPoint(-axis.y, axis.x));
  }
  if (axes || parallel || perpendicular) {
    for (final w in model.walls.values) {
      if (excludeWalls.contains(w.id)) continue;
      final connected = axes &&
          (projectToSegment(anchor, model.corners[w.start]!,
                          model.corners[w.end]!) -
                      anchor)
                  .length <
              .001;
      final axis = model.corners[w.end]! - model.corners[w.start]!;
      for (final direction in [
        if (parallel || connected) axis,
        if (perpendicular || connected) DrawingPoint(-axis.y, axis.x)
      ]) {
        along(direction);
      }
    }
  }
  var best = tolerance;
  for (final candidate in candidates) {
    final distance = (candidate - point).length;
    if (distance < best) {
      best = distance;
      result = candidate;
    }
  }
  return result;
}
