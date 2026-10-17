import 'dart:math' as math;
import 'drawing_point.dart';
import 'wall_network.dart';

/// Screen-plan direction: 0 is right, 90 is down; independent of camera zoom.
double directionDegrees(DrawingPoint from, DrawingPoint to) {
  final d = to - from;
  return (math.atan2(d.y, d.x) * 180 / math.pi + 360) % 360;
}

class CornerAngle {
  const CornerAngle(this.corner, this.first, this.second);
  final DrawingPoint corner, first, second;
  double get radians {
    final a = first - corner, b = second - corner;
    if (a.length == 0 || b.length == 0) return 0;
    return math.acos((a.dot(b) / (a.length * b.length)).clamp(-1.0, 1.0));
  }

  double get degrees => radians * 180 / math.pi;
}

List<CornerAngle> contextualAngles(WallNetwork model,
    {int? wall, int? corner, List<DrawingPoint> preview = const []}) {
  if (preview.length >= 3) {
    return [
      CornerAngle(preview[preview.length - 2], preview[preview.length - 3],
          preview.last)
    ];
  }
  if (preview.length == 2) {
    final node = model.nearestCorner(preview.first, .001);
    if (node == null) {
      final id = model.nearestWall(preview.first, .001);
      if (id == null) return [];
      final existing = model.walls[id]!;
      return [
        for (final endpoint in [existing.start, existing.end])
          CornerAngle(preview.first, model.corners[endpoint]!, preview.last)
      ];
    }
    return [
      for (final w in model.walls.values)
        if (w.start == node || w.end == node)
          CornerAngle(preview.first,
              model.corners[w.start == node ? w.end : w.start]!, preview.last)
    ].take(2).toList();
  }
  if (preview.isNotEmpty) return [];
  final chosen = wall == null ? null : model.walls[wall];
  final nodes = corner != null
      ? [corner]
      : chosen == null
          ? <int>[]
          : [chosen.start, chosen.end];
  final result = <CornerAngle>[];
  for (final node in nodes) {
    final attached = model.walls.values
        .where((w) => w.start == node || w.end == node)
        .toList();
    if (attached.length < 2) continue;
    final primary = chosen != null && attached.any((w) => w.id == chosen.id)
        ? chosen
        : attached.first;
    for (final other in attached.where((w) => w.id != primary.id)) {
      result.add(CornerAngle(
          model.corners[node]!,
          model.corners[primary.start == node ? primary.end : primary.start]!,
          model.corners[other.start == node ? other.end : other.start]!));
      if (result.length == 2) return result;
    }
  }
  return result;
}
