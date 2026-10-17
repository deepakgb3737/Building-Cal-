import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;
import '../models/resize_handle.dart';

/// Utility functions for path manipulation and shape creation
class PathUtils {
  /// Scale a path by sx and sy around an anchor point
  static Path scalePath(Path path, double sx, double sy, Offset anchor) {
    final matrix = Matrix4.identity()
      ..translateByVector3(Vector3(anchor.dx, anchor.dy, 0))
      ..scaleByVector3(Vector3(sx, sy, 1))
      ..translateByVector3(Vector3(-anchor.dx, -anchor.dy, 0));
    return path.transform(matrix.storage);
  }

  /// Rotate a path by degrees around a center point
  static Path rotatePath(Path path, double deg, Offset center) {
    final rad = deg * math.pi / 180;
    final m = Matrix4.identity()
      ..translateByVector3(Vector3(center.dx, center.dy, 0))
      ..rotateZ(rad)
      ..translateByVector3(Vector3(-center.dx, -center.dy, 0));
    return path.transform(m.storage);
  }

  /// Cut a door opening from a room path
  static Path cutDoorFromRoom(Path room, Path door) {
    return Path.combine(PathOperation.difference, room, door);
  }

  /// Hit test for resize handles
  static ResizeHandle? hitTestHandle(Offset pos, Rect bounds) {
    const size = 12.0;
    final handles = {
      ResizeHandle.top: Rect.fromCenter(
          center: bounds.topCenter, width: size * 2, height: size * 2),
      ResizeHandle.bottom: Rect.fromCenter(
          center: bounds.bottomCenter, width: size * 2, height: size * 2),
      ResizeHandle.left: Rect.fromCenter(
          center: bounds.centerLeft, width: size * 2, height: size * 2),
      ResizeHandle.right: Rect.fromCenter(
          center: bounds.centerRight, width: size * 2, height: size * 2),
      ResizeHandle.topLeft: Rect.fromLTWH(
        bounds.left - size,
        bounds.top - size,
        size * 2,
        size * 2,
      ),
      ResizeHandle.topRight: Rect.fromLTWH(
        bounds.right - size,
        bounds.top - size,
        size * 2,
        size * 2,
      ),
      ResizeHandle.bottomLeft: Rect.fromLTWH(
        bounds.left - size,
        bounds.bottom - size,
        size * 2,
        size * 2,
      ),
      ResizeHandle.bottomRight: Rect.fromLTWH(
        bounds.right - size,
        bounds.bottom - size,
        size * 2,
        size * 2,
      ),
    };

    for (final e in handles.entries) {
      if (e.value.contains(pos)) return e.key;
    }
    return null;
  }

  // Shape creation functions
  static Path createLShape(Offset o) {
    return Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + 200, o.dy)
      ..lineTo(o.dx + 200, o.dy + 50)
      ..lineTo(o.dx + 50, o.dy + 50)
      ..lineTo(o.dx + 50, o.dy + 200)
      ..lineTo(o.dx, o.dy + 200)
      ..close();
  }

  static Path createUShape(Offset o) {
    return Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + 200, o.dy)
      ..lineTo(o.dx + 200, o.dy + 200)
      ..lineTo(o.dx + 150, o.dy + 200)
      ..lineTo(o.dx + 150, o.dy + 50)
      ..lineTo(o.dx + 50, o.dy + 50)
      ..lineTo(o.dx + 50, o.dy + 200)
      ..lineTo(o.dx, o.dy + 200)
      ..close();
  }

  static Path createTShape(Offset o) {
    return Path()
      ..moveTo(o.dx + 50, o.dy)
      ..lineTo(o.dx + 150, o.dy)
      ..lineTo(o.dx + 150, o.dy + 100)
      ..lineTo(o.dx + 200, o.dy + 100)
      ..lineTo(o.dx + 200, o.dy + 150)
      ..lineTo(o.dx, o.dy + 150)
      ..lineTo(o.dx, o.dy + 100)
      ..lineTo(o.dx + 50, o.dy + 100)
      ..close();
  }

  static Path createRectangle(Offset o,
      {double width = 200, double height = 150}) {
    return Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + width, o.dy)
      ..lineTo(o.dx + width, o.dy + height)
      ..lineTo(o.dx, o.dy + height)
      ..close();
  }

  static Path createCircle(Offset center, {double radius = 100}) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  static Path createDoor(Offset center,
      {double width = 50, double height = 12}) {
    // Door as a rectangle on the border
    return Path()
      ..addRect(Rect.fromCenter(center: center, width: width, height: height));
  }
}
