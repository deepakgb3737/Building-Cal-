import 'dart:math' as math;
import 'drawing_point.dart';
import 'drawing_shapes.dart';
import 'wall_network.dart';
import 'drawing_precision.dart';

/// Sketch candidates in mm. Neither candidate mutates the connected wall graph.
class SketchRefinement {
  const SketchRefinement(this.original, this.refined, this.shape,
      {this.dashed = false});
  final bool dashed;
  final List<DrawingPoint> original, refined;
  final ShapePreset? shape;

  static SketchRefinement fromStroke(List<DrawingPoint> input,
      {required double tolerance,
      bool recognize = true,
      bool align = false,
      WallNetwork? existing}) {
    if (!tolerance.isFinite ||
        tolerance <= 0 ||
        input.any((p) => !p.isFinite)) {
      throw ArgumentError(
          'A sketch needs finite points and a positive tolerance.');
    }
    final samples = <DrawingPoint>[];
    for (final p in input) {
      if (samples.isEmpty || (p - samples.last).length >= 10) {
        samples.add(p);
      }
    }
    if (samples.length > 1 &&
        input.isNotEmpty &&
        (input.last - samples.last).length > .001) {
      if ((input.last - samples[samples.length - 2]).length >= 10) {
        samples[samples.length - 1] = input.last;
      }
    }
    if (samples.length < 2) {
      return SketchRefinement(List.of(samples), List.of(samples), null);
    }
    var minX = samples.first.x, maxX = minX;
    var minY = samples.first.y, maxY = minY;
    for (final p in samples) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final extent = DrawingPoint(maxX - minX, maxY - minY).length;
    final adaptive = math.min(tolerance, math.max(1.0, extent * .012));
    // The original removes only sub-wall-size jitter, never squares off corners.
    final original = straightenStroke(samples, math.min(1.0, adaptive * .1));
    var reduced = straightenStroke(samples, adaptive);
    // Global simplification can retain a jitter point after its neighbours settle.
    final clean = <DrawingPoint>[];
    for (final point in reduced) {
      while (clean.length > 1) {
        final a = clean[clean.length - 2], b = clean.last;
        if ((b - a).dot(point - b) <= 0 ||
            (b - projectToSegment(b, a, point)).length > adaptive) {
          break;
        }
        clean.removeLast();
      }
      clean.add(point);
    }
    if (clean.length < reduced.length) {
      // Verify the original spans so consecutive removals cannot flatten a curve.
      var cursor = 0, safe = true;
      for (var i = 1; i < clean.length && safe; i++) {
        while (cursor < samples.length) {
          final sample = samples[cursor++];
          if ((sample - projectToSegment(sample, clean[i - 1], clean[i]))
                  .length >
              adaptive) {
            safe = false;
            break;
          }
          if (identical(sample, clean[i])) break;
        }
      }
      if (safe) reduced = clean;
    }
    final gap = (reduced.first - reduced.last).length;
    if (recognize &&
        reduced.length >= 4 &&
        gap > .001 &&
        gap <= math.min(tolerance * 4, extent * .02)) {
      final closed = [...reduced]..last = reduced.first;
      try {
        final check = WallNetwork()..addPolyline(closed);
        if (check.walls.length == closed.length - 1 &&
            check.corners.length == closed.length - 1) {
          reduced = closed;
        }
      } on DrawingConflict {
        // Ambiguous closure keeps the open stroke instead of guessing topology.
      }
    }
    final shape = recognize ? recognizeShape(reduced) : null;
    var refined = shape?.points ?? reduced;
    if (align && refined.length == 2) {
      final first = refined.first, last = refined.last;
      final firstAttached = existing?.nearestWall(first, .001) != null;
      final lastAttached = existing?.nearestWall(last, .001) != null;
      if (!(firstAttached && lastAttached)) {
        final anchor = lastAttached ? last : first;
        final end = lastAttached ? first : last;
        final nearby = WallNetwork();
        if (existing != null) {
          for (final wall in existing.walls.values) {
            final a = existing.corners[wall.start]!;
            final b = existing.corners[wall.end]!;
            if ((anchor - projectToSegment(anchor, a, b)).length <=
                tolerance * 12) {
              nearby.addPolyline([a, b]);
            }
          }
        }
        final aligned = precisionPoint(nearby, end,
            anchor: anchor,
            axes: true,
            parallel: true,
            perpendicular: true,
            tolerance: adaptive);
        // Alignment is not a connection request: never snap to nearby endpoints.
        if ((aligned - end).length > .001 &&
            (existing == null || existing.nearestWall(aligned, .001) == null) &&
            samples.every((p) =>
                (p - projectToSegment(p, anchor, aligned)).length <=
                adaptive)) {
          refined = lastAttached ? [aligned, anchor] : [anchor, aligned];
        }
      }
    }
    try {
      (existing?.copy() ?? WallNetwork()).addPolyline(refined);
    } on DrawingConflict {
      // A shortcut can shift intersections and create sub-minimum wall pieces.
      return SketchRefinement(original, List.of(original), null);
    }
    return SketchRefinement(original, refined, shape?.kind);
  }

  static (WallNetwork, List<DrawingPoint>) straightenChain(
      WallNetwork model, int selected,
      {required double tolerance}) {
    if (!tolerance.isFinite || tolerance <= 0) {
      throw ArgumentError.value(tolerance, 'tolerance');
    }
    final wall = model.walls[selected];
    if (wall == null) throw const DrawingConflict('Select an existing wall.');
    bool protected(int id) =>
        model.isFixed(id) ||
        model.relations.any((relation) => relation.touches({id}));
    if (protected(selected)) {
      throw const DrawingConflict(
          'Unlock the wall and its constraints before straightening.');
    }
    final adjacency = <int, List<int>>{};
    for (final edge in model.walls.values) {
      adjacency.putIfAbsent(edge.start, () => []).add(edge.id);
      adjacency.putIfAbsent(edge.end, () => []).add(edge.id);
    }
    final ids = <int>{selected}, nodes = [wall.start, wall.end];
    final origin = model.corners[wall.start]!;
    final axis = model.corners[wall.end]! - origin;
    for (final prepend in [true, false]) {
      while (true) {
        final node = prepend ? nodes.first : nodes.last;
        final linked = adjacency[node]!;
        if (linked.length != 2) break;
        final nextId =
            linked.firstWhere((id) => !ids.contains(id), orElse: () => -1);
        if (nextId == -1 ||
            protected(nextId) ||
            model.walls[nextId]!.dashed != wall.dashed) {
          break;
        }
        final edge = model.walls[nextId]!;
        final other = edge.start == node ? edge.end : edge.start;
        final point = model.corners[other]!;
        final direction = point - model.corners[node]!;
        final inward =
            model.corners[prepend ? nodes[1] : nodes[nodes.length - 2]]! -
                model.corners[node]!;
        if (nodes.contains(other) ||
            direction.dot(inward) >= 0 ||
            direction.cross(axis).abs() / (direction.length * axis.length) >
                math.sin(math.pi / 18)) {
          break;
        }
        ids.add(nextId);
        if (prepend) {
          nodes.insert(0, other);
        } else {
          nodes.add(other);
        }
      }
    }
    final points = nodes.map((id) => model.corners[id]!).toList();
    if (points.any((p) =>
        (p - projectToSegment(p, points.first, points.last)).length >
        tolerance)) {
      throw const DrawingConflict(
          'This chain has a meaningful bend; refine the sketch instead.');
    }
    if (ids.length < 2) {
      throw const DrawingConflict(
          'No redundant connected segments to straighten.');
    }
    final next = model.copy();
    for (final id in ids) {
      next.deleteWall(id);
    }
    next.addPolyline([points.first, points.last], dashed: wall.dashed);
    for (final edge in model.walls.values.where((w) => !ids.contains(w.id))) {
      final retained = next.walls[edge.id];
      if (retained == null ||
          retained.start != edge.start ||
          retained.end != edge.end) {
        throw const DrawingConflict(
            'Straightening would change a neighbouring junction.');
      }
      for (final node in [edge.start, edge.end]) {
        final point = model.corners[node]!;
        if (node != nodes.first &&
            node != nodes.last &&
            (point - projectToSegment(point, points.first, points.last))
                    .length <
                .001) {
          throw const DrawingConflict(
              'Straightening would create an unintended connection.');
        }
      }
    }
    return (next, [points.first, points.last]);
  }
}
