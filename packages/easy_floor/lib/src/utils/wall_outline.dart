import 'dart:math' as math;
import 'package:flutter/material.dart';

abstract final class WallOutline {
  static List<Offset> straighten(List<Offset> stroke) {
    if (stroke.length < 3) return [];
    final bounds = (Path()..addPolygon(stroke, false)).getBounds();
    final diagonal = bounds.size.longestSide;
    final tolerance = (diagonal * .025).clamp(4.0, 12.0);
    final closeDistance = (diagonal * .06).clamp(8.0, 24.0);
    if ((stroke.last - stroke.first).distance > closeDistance) {
      throw ArgumentError(
          'Finish the outline near its starting point to close the room.');
    }
    final clean = <Offset>[];
    for (final point in stroke) {
      var loopStart = -1;
      for (var j = clean.length - 2; j >= math.max(0, clean.length - 64); j--) {
        if ((clean[j] - point).distance > tolerance / 2) continue;
        if (clean.skip(j).every((p) => (p - point).distance <= tolerance * 3)) {
          loopStart = j;
          break;
        }
      }
      if (loopStart >= 0) clean.removeRange(loopStart + 1, clean.length);
      if (clean.isEmpty || (clean.last - point).distance > .1) clean.add(point);
    }
    while (clean.length > 1 &&
        (clean.last - clean.first).distance <= closeDistance) {
      clean.removeLast();
    }
    // shortcut: deviations below 4–12 cm are smoothed; use finer tolerance for detail drawings.
    final points = _simplify([...clean, clean.first], tolerance)..removeLast();
    if (points.length < 3) return [];
    final xGroups = List.generate(points.length, (i) => i);
    final yGroups = List.generate(points.length, (i) => i);
    int root(List<int> groups, int i) {
      while (groups[i] != i) {
        i = groups[i];
      }
      return i;
    }

    for (var i = 0; i < points.length; i++) {
      final next = (i + 1) % points.length;
      final delta = points[next] - points[i];
      final threshold = math.tan(10 * math.pi / 180);
      if (delta.dy.abs() <= delta.dx.abs() * threshold) {
        yGroups[root(yGroups, next)] = root(yGroups, i);
      } else if (delta.dx.abs() <= delta.dy.abs() * threshold) {
        xGroups[root(xGroups, next)] = root(xGroups, i);
      }
    }
    double average(List<int> groups, int index, bool x) {
      final group = root(groups, index);
      final members = [
        for (var i = 0; i < points.length; i++)
          if (root(groups, i) == group) x ? points[i].dx : points[i].dy
      ];
      return members.reduce((a, b) => a + b) / members.length;
    }

    final aligned = [
      for (var i = 0; i < points.length; i++)
        Offset(average(xGroups, i, true), average(yGroups, i, false))
    ];
    // A collapsed stroke is not a usable room outline.
    double area = 0;
    for (var i = 0; i < aligned.length; i++) {
      final a = aligned[i];
      final b = aligned[(i + 1) % aligned.length];
      area += a.dx * b.dy - b.dx * a.dy;
    }
    return area.abs() < 2 ? [] : aligned;
  }

  static List<Offset> _simplify(List<Offset> points, double tolerance) {
    if (points.length <= 2) return points;
    final start = points.first;
    final delta = points.last - start;
    final squaredLength = delta.distanceSquared;
    var maximum = 0.0;
    var index = 0;
    for (var i = 1; i < points.length - 1; i++) {
      final offset = points[i] - start;
      final t = squaredLength == 0
          ? 0.0
          : ((offset.dx * delta.dx + offset.dy * delta.dy) / squaredLength)
              .clamp(0.0, 1.0);
      final distance = (points[i] - (start + delta * t)).distance;
      if (distance > maximum) {
        maximum = distance;
        index = i;
      }
    }
    if (maximum <= tolerance) return [points.first, points.last];
    return [
      ..._simplify(points.sublist(0, index + 1), tolerance)..removeLast(),
      ..._simplify(points.sublist(index), tolerance)
    ];
  }
}
