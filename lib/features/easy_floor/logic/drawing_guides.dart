import 'drawing_point.dart';
import 'wall_network.dart';

enum GuideKind {
  horizontal,
  vertical,
  extension,
  centerline,
  parallel,
  perpendicular
}

class DrawingGuide {
  const DrawingGuide(this.key, this.kind, this.start, this.end, this.target);
  final String key;
  final GuideKind kind;
  final DrawingPoint start, end, target;
}

/// Align the actual moving corners, not an arbitrary first corner of the room.
List<DrawingGuide> roomMovementGuides(
    WallNetwork model, Set<int> movingNodes, double tolerance) {
  final best = <GuideKind, (double, double, DrawingGuide)>{};
  for (final id in movingNodes) {
    final p = model.corners[id]!;
    for (final entry in model.corners.entries) {
      if (movingNodes.contains(entry.key)) continue;
      final target = entry.value, distance = (p - target).length;
      if (distance > tolerance * 12) continue;
      for (final vertical in [false, true]) {
        final error =
            vertical ? (p.x - target.x).abs() : (p.y - target.y).abs();
        if (error > tolerance) continue;
        final kind = vertical ? GuideKind.vertical : GuideKind.horizontal;
        final guide = DrawingGuide(
            'room${kind.name}$id:${entry.key}',
            kind,
            target,
            vertical
                ? DrawingPoint(target.x, p.y)
                : DrawingPoint(p.x, target.y),
            target);
        if ((guide.end - guide.start).length < tolerance) continue;
        final previous = best[kind];
        if (previous == null ||
            error < previous.$1 ||
            (error == previous.$1 &&
                (distance < previous.$2 ||
                    (distance == previous.$2 &&
                        guide.key.compareTo(previous.$3.key) < 0)))) {
          best[kind] = (error, distance, guide);
        }
      }
    }
  }
  return best.values.map((candidate) => candidate.$3).toList();
}

/// Display-only candidates in mm; tolerance is converted from pixels by the UI.
List<DrawingGuide> drawingGuides(
    WallNetwork model, DrawingPoint point, double tolerance,
    {DrawingPoint? anchor,
    Set<int> exclude = const {},
    List<DrawingGuide> previous = const []}) {
  final candidates = <(double, double, DrawingGuide)>[];
  void add(double distance, DrawingGuide guide,
      {double referenceDistance = 0}) {
    if (distance > tolerance || (guide.end - guide.start).length < tolerance) {
      return;
    }
    final retained = previous.any((g) => g.key == guide.key);
    candidates.add(
        (distance - (retained ? tolerance * .2 : 0), referenceDistance, guide));
  }

  if (anchor != null) {
    add(
        (point.y - anchor.y).abs(),
        DrawingGuide('axisH', GuideKind.horizontal, anchor,
            DrawingPoint(point.x, anchor.y), anchor));
    add(
        (point.x - anchor.x).abs(),
        DrawingGuide('axisV', GuideKind.vertical, anchor,
            DrawingPoint(anchor.x, point.y), anchor));
  }

  for (final entry in model.corners.entries) {
    if (exclude.contains(entry.key)) continue;
    final p = entry.value;
    add(
        (p.y - point.y).abs(),
        DrawingGuide('h${entry.key}', GuideKind.horizontal, p,
            DrawingPoint(point.x, p.y), p));
    add(
        (p.x - point.x).abs(),
        DrawingGuide('v${entry.key}', GuideKind.vertical, p,
            DrawingPoint(p.x, point.y), p));
  }
  for (final wall in model.walls.values) {
    if (exclude.contains(wall.start) || exclude.contains(wall.end)) continue;
    final a = model.corners[wall.start]!, b = model.corners[wall.end]!;
    final d = b - a;
    final t = (point - a).dot(d) / d.dot(d);
    final projection = a + d * t;
    if (t < 0 || t > 1) {
      add((projection - point).length,
          DrawingGuide('e${wall.id}', GuideKind.extension, a, projection, b));
    } else {
      add((projection - point).length,
          DrawingGuide('c${wall.id}', GuideKind.centerline, a, b, projection));
    }
    if (anchor != null && (point - anchor).length > tolerance * 4) {
      for (final perpendicular in [false, true]) {
        final direction = perpendicular ? DrawingPoint(-d.y, d.x) : d;
        final along =
            (point - anchor).dot(direction) / direction.dot(direction);
        final end = anchor + direction * along;
        add(
            (point - end).length,
            DrawingGuide(
                '${perpendicular ? 'r' : 'p'}${wall.id}',
                perpendicular ? GuideKind.perpendicular : GuideKind.parallel,
                anchor,
                end,
                (a + b) * .5),
            referenceDistance:
                (anchor - projectToSegment(anchor, a, b)).length);
      }
    }
  }
  candidates.sort((a, b) {
    final order = a.$1.compareTo(b.$1);
    if (order != 0) return order;
    int rank(DrawingGuide g) =>
        g.kind == GuideKind.parallel || g.kind == GuideKind.perpendicular
            ? 0
            : 1;
    final relevance = rank(a.$3).compareTo(rank(b.$3));
    if (relevance != 0) return relevance;
    final distance = a.$2.compareTo(b.$2);
    return distance != 0 ? distance : a.$3.key.compareTo(b.$3.key);
  });
  final chosen = <DrawingGuide>[];
  for (final candidate in candidates) {
    final guide = candidate.$3;
    if (chosen.any((g) {
      if (g.kind == guide.kind) return true;
      final a = g.end - g.start, b = guide.end - guide.start;
      return a.cross(b).abs() / (a.length * b.length) < .01;
    })) {
      continue;
    }
    chosen.add(guide);
    if (chosen.length == 2) break;
  }
  return chosen;
}
