import '../models/room.dart';
import '../models/door.dart';
import 'path_utils.dart';
import 'package:flutter/material.dart';

enum DimensionUnit {
  millimetres('Millimetres', 'mm', 1),
  metres('Metres', 'm', 1000),
  feet('Feet', 'ft', 304.8);

  const DimensionUnit(this.label, this.symbol, this.millimetresPerUnit);
  final String label;
  final String symbol;
  final double millimetresPerUnit;
  double toMm(double value) => value * millimetresPerUnit;
  double fromMm(double value) => value / millimetresPerUnit;
}

abstract final class RoomDimensions {
  static void resize(
      Room room, List<Door> doors, double widthMm, double lengthMm) {
    for (final dimension in [widthMm, lengthMm]) {
      if (!dimension.isFinite || dimension < 100 || dimension > 1000000) {
        throw ArgumentError('Dimensions must be 100 to 1000000 mm.');
      }
    }
    final bounds = room.path.getBounds();
    if (bounds.width <= 0 || bounds.height <= 0) {
      throw ArgumentError('Draw a room with width and length first.');
    }
    final sx = widthMm / 10 / bounds.width;
    final sy = lengthMm / 10 / bounds.height;
    scale(room, doors, sx, sy, bounds.topLeft);
  }

  static void scale(
      Room room, List<Door> doors, double sx, double sy, Offset anchor) {
    room.path = PathUtils.scalePath(room.path, sx, sy, anchor);
    room.wallPoints = room.wallPoints
        ?.map((p) => Offset(anchor.dx + (p.dx - anchor.dx) * sx,
            anchor.dy + (p.dy - anchor.dy) * sy))
        .toList();
    for (var i = 0; i < room.doorOpenings.length; i++) {
      room.doorOpenings[i] =
          PathUtils.scalePath(room.doorOpenings[i], sx, sy, anchor);
    }
    for (final door in doors.where((door) => door.roomId == room.id)) {
      door.path = PathUtils.scalePath(door.path, sx, sy, anchor);
    }
  }

  static void move(Room room, List<Door> doors, Offset delta) {
    room.path = room.path.shift(delta);
    room.wallPoints = room.wallPoints?.map((p) => p + delta).toList();
    for (var i = 0; i < room.doorOpenings.length; i++) {
      room.doorOpenings[i] = room.doorOpenings[i].shift(delta);
    }
    for (final door in doors.where((door) => door.roomId == room.id)) {
      door.path = door.path.shift(delta);
    }
  }
}
