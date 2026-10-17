import 'package:flutter/material.dart';
import '../models/room.dart';
import '../models/door.dart';

abstract final class WallDimensions {
  static void resize(Room room, List<Door> doors, int index, double lengthMm) {
    final points = room.wallPoints;
    if (points == null || index < 0 || index >= points.length) {
      throw ArgumentError('Select a wall in a drawn room.');
    }
    if (!lengthMm.isFinite || lengthMm < 100 || lengthMm > 1000000) {
      throw ArgumentError('Wall length must be 100 to 1000000 mm.');
    }
    if (doors.any((door) => door.roomId == room.id)) {
      throw ArgumentError(
          'Remove this room’s doors before editing walls, then place them again.');
    }
    final next = (index + 1) % points.length;
    final start = points[index];
    final end = points[next];
    final direction = end - start;
    if (direction.distance < .001)
      throw ArgumentError('This wall has no length.');
    final moved = start + direction / direction.distance * (lengthMm / 10);
    final delta = moved - end;
    final horizontal = direction.dy.abs() < .001;
    final vertical = direction.dx.abs() < .001;
    final updated = [
      for (var i = 0; i < points.length; i++)
        horizontal && (points[i].dx - end.dx).abs() < .001
            ? points[i] + Offset(delta.dx, 0)
            : vertical && (points[i].dy - end.dy).abs() < .001
                ? points[i] + Offset(0, delta.dy)
                : i == next
                    ? moved
                    : points[i]
    ];
    _apply(room, updated);
  }

  static void moveCorner(Room room, List<Door> doors, int index, Offset delta) {
    final points = room.wallPoints;
    if (points == null ||
        index < 0 ||
        index >= points.length ||
        !delta.dx.isFinite ||
        !delta.dy.isFinite) throw ArgumentError('Select a room corner.');
    if (doors.any((door) => door.roomId == room.id))
      throw ArgumentError('Remove doors before reshaping walls.');
    _apply(room, [
      for (var i = 0; i < points.length; i++)
        i == index ? points[i] + delta : points[i]
    ]);
  }

  static void _apply(Room room, List<Offset> updated) {
    validate(updated);
    room.wallPoints = updated;
    room.path = Path()..addPolygon(updated, true);
  }

  static void validate(List<Offset> updated) {
    if (updated.length < 3 ||
        updated.any((p) => !p.dx.isFinite || !p.dy.isFinite)) {
      throw ArgumentError('Draw a closed room with at least three corners.');
    }
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
    double area = 0;
    for (var i = 0; i < updated.length; i++) {
      final a = updated[i];
      final b = updated[(i + 1) % updated.length];
      if ((b - a).distance < 10) {
        throw ArgumentError(
            'That size makes another wall smaller than 100 mm.');
      }
      area += cross(a, b);
      for (var j = i + 1; j < updated.length; j++) {
        if (j == i + 1 || (i == 0 && j == updated.length - 1)) continue;
        final c = updated[j];
        final d = updated[(j + 1) % updated.length];
        final ab = b - a;
        final cd = d - c;
        final determinant = cross(ab, cd);
        if (determinant.abs() < 1e-9) {
          if (cross(c - a, ab).abs() < 1e-9) {
            final t0 =
                ((c - a).dx * ab.dx + (c - a).dy * ab.dy) / ab.distanceSquared;
            final t1 =
                ((d - a).dx * ab.dx + (d - a).dy * ab.dy) / ab.distanceSquared;
            if ((t0 <= 1 && t1 >= 0) || (t1 <= 1 && t0 >= 0)) {
              throw ArgumentError('Walls overlap. Adjust the outline.');
            }
          }
          continue;
        }
        final t = cross(c - a, cd) / determinant;
        final u = cross(c - a, ab) / determinant;
        if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
          throw ArgumentError(
              'That size makes walls cross. Choose a different length.');
        }
      }
    }
    if (area.abs() < 2) throw ArgumentError('That size collapses the room.');
  }
}
